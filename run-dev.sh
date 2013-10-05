#!/bin/bash
set -e

cd perl
carton install
carton exec plackup -s Starman -p 5000 -E prod --workers 1 --disable-keepalive app.psgi