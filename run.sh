#!/bin/zsh
set -e

cd perl
carton install
exec carton exec plackup -s Starman -p 5000 -E prod --workers 10 --disable-keepalive app.psgi