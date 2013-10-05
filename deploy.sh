#!/bin/zsh
set -e
set -x

REMOTE_SERVER="ec2-54-238-158-189.ap-northeast-1.compute.amazonaws.com"
REMOTE_APP_DIR="webapp"

ssh isucon@$REMOTE_SERVER flock -x /tmp/isucon.deploy.lock bash -xc 'cd $REMOTE_APP_DIR; git pull; ./restart.sh'