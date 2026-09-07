#!/bin/sh

MIHOMO="/root/libernet/core/mihomo"
CFG="/root/libernet/config/mihomo.yaml"
LOG="/root/libernet/log/clash.log"

case "$1" in

start)
    killall mihomo >/dev/null 2>&1

    : > "$LOG"

    "$MIHOMO" -d /root/libernet -f "$CFG" > "$LOG" 2>&1 &
;;

stop)
    killall mihomo >/dev/null 2>&1
;;

restart)
    killall mihomo >/dev/null 2>&1

    sleep 1

    : > "$LOG"

    "$MIHOMO" -d /root/libernet -f "$CFG" > "$LOG" 2>&1 &
;;

status)
    pgrep mihomo >/dev/null
;;

esac