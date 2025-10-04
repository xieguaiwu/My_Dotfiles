#!/bin/bash
DURATION=$1
MESSAGE=$2
(sleep "$DURATION" && swaynag -m "计时器提醒" "$MESSAGE") &

