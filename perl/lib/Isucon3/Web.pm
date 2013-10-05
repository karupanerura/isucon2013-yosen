package Isucon3::Web;

use strict;
use warnings;
use utf8;
use feature qw/state/;
use Kossy;
use DBIx::Sunny;
use JSON qw/ decode_json /;
use Digest::SHA qw/ sha256_hex /;
use Data::MessagePack;
use Compress::LZ4 ();
use DBIx::Sunny;
use Path::Class;
use IO::Handle;
use Encode;
use Time::Piece;
use Text::Markdown::Hoedown;
use Cache::Memcached::Fast;

sub load_config {
    state $config = do {
        my $env  = $ENV{ISUCON_ENV} || 'local';
        my $json = file(__FILE__)->dir->parent->parent->parent->subdir('config')->file("${env}.json")->slurp;
        decode_json($json);
    };
    return $config;
}

sub cache {
    state $cache = do {
        my $msgpack = Data::MessagePack->new->utf8(1);
        Cache::Memcached::Fast->new({
            servers            => [],
            utf8               => 1,
            hash_namespace     => 1,
            ketama_points      => 150,
            compress_threshold => 5_000,
            compress_methods => [
                sub { ${$_[1]} = Compress::LZ4::compress(${$_[0]})   },
                sub { ${$_[1]} = Compress::LZ4::decompress(${$_[0]}) },
            ],
            serialize_methods => [
                sub { $msgpack->pack($_[0])   },
                sub { $msgpack->unpack($_[0]) },
            ],
        });
    };
    return $cache;
}

sub dbh {
    my ($self) = @_;
    $self->{_dbh} ||= do {
        my $dbconf = $self->load_config->{database};
        DBIx::Sunny->connect(
            "dbi:mysql:database=${$dbconf}{dbname};host=${$dbconf}{host};port=${$dbconf}{port}", $dbconf->{username}, $dbconf->{password}, {
                RaiseError => 1,
                PrintError => 0,
                AutoInactiveDestroy => 1,
                mysql_enable_utf8   => 1,
                mysql_auto_reconnect => 1,
            },
        );
    };
}

filter 'session' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        my $sid = $c->req->env->{"psgix.session.options"}->{id};
        $c->stash->{session_id} = $sid;
        $c->stash->{session}    = $c->req->env->{"psgix.session"};
        $app->($self, $c);
    };
};

filter 'get_user' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;

        my $user_id = $c->req->env->{"psgix.session"}->{user_id};
        my $user = $self->dbh->select_row(
            'SELECT * FROM users WHERE id=?',
            $user_id,
        );
        $c->stash->{user} = $user;
        $c->res->header('Cache-Control', 'private') if $user;
        $app->($self, $c);
    }
};

filter 'require_user' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        unless ( $c->stash->{user} ) {
            return $c->redirect('/');
        }
        $app->($self, $c);
    };
};

filter 'anti_csrf' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        my $sid   = $c->req->param('sid');
        my $token = $c->req->env->{"psgix.session"}->{token};
        if ( $sid ne $token ) {
            return $c->halt(400);
        }
        $app->($self, $c);
    };
};

sub public_total_memo {
    my $self = shift;
    return $self->dbh->select_one(
        'SELECT count FROM public_total_memo'
    );
}

get '/' => [qw(session get_user)] => sub {
    my ($self, $c) = @_;

    my $total = $self->public_total_memo();
    my $memos = $self->dbh->select_all(
        'SELECT id, content, username, created_at FROM memos WHERE is_private=0 ORDER BY created_at DESC LIMIT 100',
    );

    $c->render('index.tx', {
        memos => $memos, 
        page  => 0,
        total => $total,
    });
};

get '/recent/:page' => [qw(session get_user)] => sub {
    my ($self, $c) = @_;
    my $page  = int $c->args->{page};
    my $total = $self->public_total_memo();
    my $memos = $self->dbh->select_all(
        sprintf("SELECT id, content, username, created_at FROM memos WHERE is_private=0 ORDER BY created_at DESC LIMIT 100 OFFSET %d", $page * 100)
    );
    if ( @$memos == 0 ) {
        return $c->halt(404);
    }

    $c->render('index.tx', {
        memos => $memos,
        page  => $page,
        total => $total,
    });
};

get '/signin' => [qw(session get_user)] => sub {
    my ($self, $c) = @_;
    $c->render('signin.tx', {});
};

post '/signout' => [qw(session get_user require_user anti_csrf)] => sub {
    my ($self, $c) = @_;
    $c->req->env->{"psgix.session.options"}->{change_id} = 1;
    delete $c->req->env->{"psgix.session"}->{user_id};
    $c->redirect('/');
};

post '/signup' => [qw(session anti_csrf)] => sub {
    my ($self, $c) = @_;

    my $username = $c->req->param("username");
    my $password = $c->req->param("password");
    my $user = $self->dbh->select_row(
        'SELECT id, username, password, salt FROM users WHERE username=?',
        $username,
    );
    if ($user) {
        $c->halt(400);
    }
    else {
        my $salt = substr( sha256_hex( time() . $username ), 0, 8 );
        my $password_hash = sha256_hex( $salt, $password );
        $self->dbh->query(
            'INSERT INTO users (username, password, salt) VALUES (?, ?, ?)',
            $username, $password_hash, $salt,
        );
        my $user_id = $self->dbh->last_insert_id;
        $c->req->env->{"psgix.session"}->{user_id} = $user_id;
        $c->redirect('/mypage');
    }
};

post '/signin' => [qw(session)] => sub {
    my ($self, $c) = @_;

    my $username = $c->req->param("username");
    my $password = $c->req->param("password");
    my $user = $self->dbh->select_row(
        'SELECT id, username, password, salt FROM users WHERE username=?',
        $username,
    );
    if ( $user && $user->{password} eq sha256_hex($user->{salt} . $password) ) {
        $c->req->env->{"psgix.session.options"}->{change_id} = 1;
        my $session = $c->req->env->{"psgix.session"};
        $session->{user_id} = $user->{id};
        $session->{token}   = sha256_hex(rand());
        $self->dbh->query(
            'UPDATE users SET last_access=now() WHERE id=?',
            $user->{id},
        );
        return $c->redirect('/mypage');
    }
    else {
        $c->render('signin.tx', {});
    }
};

get '/mypage' => [qw(session get_user require_user)] => sub {
    my ($self, $c) = @_;

    my $memos = $self->dbh->select_all(
        'SELECT id, content, is_private, created_at FROM memos WHERE user=? ORDER BY created_at DESC',
        $c->stash->{user}->{id},
    );
    $c->render('mypage.tx', { memos => $memos });
};

post '/memo' => [qw(session get_user require_user anti_csrf)] => sub {
    my ($self, $c) = @_;

    my $is_private = scalar($c->req->param('is_private')) ? 1 : 0;
    {
        my $txn = $self->dbh->txn_scope;
        $self->dbh->query(
            'INSERT INTO memos (user, username, content, is_private, created_at) VALUES (?, ?, ?, ?, now())',
            $c->stash->{user}->{id},
            $c->stash->{user}->{username},
            scalar $c->req->param('content'),
            $is_private,
        );

        if (!$is_private) {
            $self->dbh->query(
                'UPDATE public_total_memo SET count = count + 1'
            );
        }
        $txn->commit;
    }
    my $memo_id = $self->dbh->last_insert_id;

    $c->redirect('/memo/' . $memo_id);
};

get '/memo/:id' => [qw(session get_user)] => sub {
    my ($self, $c) = @_;

    my $user = $c->stash->{user};
    my $memo = $self->dbh->select_row(
        'SELECT id, user, content, is_private, created_at FROM memos WHERE id=?',
        $c->args->{id},
    );
    unless ($memo) {
        $c->halt(404);
    }
    if ($memo->{is_private}) {
        if ( !$user || $user->{id} != $memo->{user} ) {
            $c->halt(404);
        }
    }
    $memo->{content_html} = markdown($memo->{content});

    my $cond;
    if ($user && $user->{id} == $memo->{user}) {
        $cond = "";
    }
    else {
        $cond = "AND is_private=0";
    }

    my $memos = $self->dbh->select_all(
        "SELECT * FROM memos WHERE user=? $cond ORDER BY created_at",
        $memo->{user},
    );
    my ($newer, $older);
    for my $i ( 0 .. scalar @$memos - 1 ) {
        if ( $memos->[$i]->{id} eq $memo->{id} ) {
            $older = $memos->[ $i - 1 ] if $i > 0;
            $newer = $memos->[ $i + 1 ] if $i < @$memos;
        }
    }

    $c->render('memo.tx', {
        memo  => $memo,
        older => $older,
        newer => $newer,
    });
};

1;
