#!/bin/zsh
set -e
set -x

ssh isucon@ec2-54-238-158-189.ap-northeast-1.compute.amazonaws.com flock -x /tmp/isucon.deploy.lock bash -c 'pwd > /dev/null; cd webapp; git pull >> ~/deploy.log 2>&1; ./restart.sh'
