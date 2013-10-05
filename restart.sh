#!/bin/bash
set -e

exec >> ~/restart.log
exec 2>&1

pkill 'starman master'
./start.sh