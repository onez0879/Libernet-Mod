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
SETTING="/root/libernet/system/config.json"
FAIL_COUNT=$(jq -r '.settings.ping.fail_count' "$SETTING")
LOG_INTERVAL=$(jq -r '.settings.ping.log_interval' "$SETTING")

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

        fi

        PING_RESULT=$(httping -c 1 -t "$TIMEOUT" "$HOST" 2>&1)
        RET=$?

        if [ "$RET" = "0" ]; then

            LATENCY=$(echo "$PING_RESULT" \
            | grep "round-trip" \
            | awk -F'=' '{print $2}' \
            | awk -F'/' '{print $2}' \
            | tr -d ' ')

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