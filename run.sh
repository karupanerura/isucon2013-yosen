#!/bin/bash
set -e

exec >> ~/run.log
exec 2>&1

cd perl
carton install
exec carton exec plackup -s Starman -p 5000 -E prod --workers 10 --disable-keepalive app.psgi