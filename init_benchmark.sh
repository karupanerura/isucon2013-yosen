#!/bin/zsh
set -e
set -x

cat /home/isucon/webapp/config/warmup.sql | mysql -uisucon isucon
cat /home/isucon/webapp/config/alter.sql | mysql -uisucon isucon
