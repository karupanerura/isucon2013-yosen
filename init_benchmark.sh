#!/bin/zsh
set -e
set -x

cat ~/webapp/config/alter_schema/alter_memo_add_username.sql | mysql -uisucon isucon
