#!/bin/zsh
set -e
set -x

mysqldump -uisucon --single-transaction --compress --order-by-primary --opt > /home/isucon/logs/mysqldump/$(date +'%Y%m%d_%H%M').sql
cat /home/isucon/webapp/config/warmup.sql | mysql -uisucon isucon
cat /home/isucon/webapp/config/alter.sql | mysql -uisucon isucon
