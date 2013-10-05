#!/bin/zsh

# brew install mysql
# ln -sfv /usr/local/opt/mysql/*.plist ~/Library/LaunchAgents
# launchctl load ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist

# brew install memcached
# ln -sfv /usr/local/opt/memcached/*.plist ~/Library/LaunchAgents
# launchctl load ~/Library/LaunchAgents/homebrew.mxcl.memcached.plist

mysql -uroot -e 'GRANT ALL ON *.* TO isucon@localhost IDENTIFIED BY ""'
mysql -uroot -e 'CREATE DATABASE isucon'