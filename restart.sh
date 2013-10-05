#!/bin/bash
exec >> ~/restart.log
exec 2>&1

ps axu | fgrep plackup | awk '{print $2}' | xargs kill
sleep 1
./start.sh
