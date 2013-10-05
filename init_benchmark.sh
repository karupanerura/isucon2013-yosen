#!/bin/zsh
set -e
set -x

cat /home/isucon/webapp/config/alter.sql | mysql -uisucon isucon
