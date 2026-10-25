#!/bin/bash

# PING Loop Wrapper
# by Lutfa Ilham
# modified by XIDZ
# v1.1

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

SERVICE_NAME="PING loop"
LIBERNET_DIR="${LIBERNET_DIR:-/root/libernet}"
SETTING="${LIBERNET_DIR}/system/config.json"
FAIL_COUNT=$(jq -r '.settings.ping.fail_count // 3' "$SETTING")
LOG_INTERVAL=$(jq -r '.settings.ping.log_interval // 5' "$SETTING")

# cek konektivitas: httping -> curl -> ping (mana yang tersedia)
check_host() {
    if command -v httping >/dev/null 2>&1; then
        OUT=$(httping -c 1 -t "$TIMEOUT" "$HOST" 2>&1) || return 1
        LATENCY=$(echo "$OUT" | grep "round-trip" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}' | tr -d ' ')
        [ -n "$LATENCY" ] || LATENCY="?"
        return 0
    fi

    URL="$HOST"
    case "$HOST" in http*|https*) ;; *) URL="http://${HOST}";; esac

    if command -v curl >/dev/null 2>&1; then
        T=$(curl -s -o /dev/null -w "%{time_total}" --max-time "$TIMEOUT" "$URL" 2>/dev/null) || return 1
        LATENCY=$(awk "BEGIN{printf \"%.1f\", ${T:-0}*1000}")
        return 0
    fi

    OUT=$(ping -c 1 -W "$TIMEOUT" "$HOST" 2>&1) || return 1
    LATENCY=$(echo "$OUT" | grep -o 'time=[0-9.]*' | head -1 | cut -d= -f2)
    [ -n "$LATENCY" ] || LATENCY="?"
    return 0
}

loop() {

    LAST_STATE=""
    COUNTER=0
    LOG_COUNTER=0

while true; do

    HOST=$(jq -r '.settings.ping.host' "$SETTING")
    INTERVAL=$(jq -r '.settings.ping.interval' "$SETTING")
    TIMEOUT=$(jq -r '.settings.ping.timeout' "$SETTING")
    ENABLE=$(jq -r '.settings.ping.enable' "$SETTING")

    if [ "$ENABLE" != "true" ]; then
        sleep 5
        continue
    fi

        LOG_COUNTER=$((LOG_COUNTER + 1))

        # cek ukuran mihomo.log tiap 30 detik
        if [ "$LOG_COUNTER" -ge 30 ]; then

            LOG_COUNTER=0

            LOG="/root/libernet/log/clash.log"

            if [ -f "$LOG" ]; then

                SIZE=$(wc -c < "$LOG" 2>/dev/null)

                # 512KB
                [ "$SIZE" -ge 524288 ] && : > "$LOG"

            fi

            # v2ray.log juga dipotong (append-mode, aman di-truncate):
            # tanpa ini file /tmp/v2ray.log membengkak puluhan MB.
            LOG="/tmp/v2ray.log"

            if [ -f "$LOG" ]; then

                SIZE=$(wc -c < "$LOG" 2>/dev/null)

                # 512KB
                [ "$SIZE" -ge 524288 ] && : > "$LOG"

            fi

            # qload.log juga dipotong: qload nulis satu baris [CONNECT]
            # per koneksi, jadi ikut membengkak kalau service jalan lama.
            LOG="/tmp/qload.log"

            if [ -f "$LOG" ]; then

                SIZE=$(wc -c < "$LOG" 2>/dev/null)

                # 512KB
                [ "$SIZE" -ge 524288 ] && : > "$LOG"

            fi

        fi

        if check_host; then

            COUNTER=$((COUNTER + 1))

            if [ "$LAST_STATE" != "UP" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:green\">[PING] ${HOST} Connected (${LATENCY} ms)</span>"

                LAST_STATE="UP"

            fi

            if [ "$COUNTER" -ge "$LOG_INTERVAL" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:green\">[PING] Tunnel Alive (${LATENCY} ms)</span>"

                COUNTER=0

            fi

        else

            COUNTER=0

            if [ "$LAST_STATE" != "DOWN" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:red\">[PING] ${HOST} Failed..!!</span>"

                LAST_STATE="DOWN"

            fi

        fi

       sleep "$INTERVAL"

    done

}

run() {

    if pgrep -f "ping-loop.sh -l" >/dev/null; then
        return 0
    fi

    "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"

    screen -AmdS ping-loop \
    "${LIBERNET_DIR}/bin/ping-loop.sh" -l

}

stop() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Stopping ${SERVICE_NAME} service"

    screen -S ping-loop -X quit >/dev/null 2>&1

}

usage() {

cat << EOF
Usage:
  -r  Run ${SERVICE_NAME} service
  -s  Stop ${SERVICE_NAME} service
EOF

}

case "$1" in
    -r) run ;;
    -s) stop ;;
    -l) loop ;;
    *) usage ;;
esac