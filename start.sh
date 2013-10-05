#!/bin/bash
set -e

exec >> ~/start.log
exec 2>&1

nohup ./run.sh &