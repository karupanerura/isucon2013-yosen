#!/bin/zsh
set -e
set -x

REMOTE_SERVER="ec2-54-238-158-189.ap-northeast-1.compute.amazonaws.com"
REMOTE_APP_DIR="webapp"

REMOTE_COMMAND=<EOF
flock -x /tmp/isucon.deploy.lock zsh -c "cd $REMOTE_APP_DIR; git pull; ./restart.sh"
EOF

ssh $REMOTE_SERVER $REMOTE_COMMAND