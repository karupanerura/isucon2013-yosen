#!/bin/bash
set -e

git pull
sudo cp mysql/my.cnf /usr/my.cnf
./init_benchmark.sh
./restart.sh