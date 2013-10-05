#!/bin/zsh
set -e
set -x

`cat config/alter_schema/alter_memo_add_username.sql > mysql -uisucon isucon`
