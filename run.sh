#!/bin/bash
set -e

exec >> ~/run.log
exec 2>&1

cd perl
../env.sh carton install
../env.sh carton exec plackup -s Starlet -p 5000 -E prod --max-workers=80 --keepalive-timeout=300 --max-keepalive-reqs=1000 --max-reqs-per-child=10240 --spawn-interval=2 app.psgi