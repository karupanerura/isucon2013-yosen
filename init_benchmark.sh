#!/bin/zsh
set -e
set -x

cat ~/webapp/config/alter.sql | mysql -uisucon isucon
