#!/bin/bash
set -e

git pull
sudo cp mysql/my.cnf /usr/my.cnf
mysql -uisucon isucon < config/dump.sql
./init_benchmark.sh
./restart.sh