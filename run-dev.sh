#!/bin/bash
set -e

cd perl
carton install
carton exec plackup -s Starlet -p 5000 -E prod --max-workers=1 app.psgi