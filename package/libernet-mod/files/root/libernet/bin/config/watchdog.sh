#!/bin/bash

# Libernet Watchdog
# replace ping-loop + auto_recon

SERVICE_NAME="Watchdog"

if [ "$(id -u)" != "0" ]; then
    echo "Run as root"
    exit 1
fi

SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

SOCKS_PORT="$(jq -r '.tun2socks.socks.port' "${SYSTEM_CONFIG}")"

[ -z "$SOCKS_PORT" ] && SOCKS_PORT="1080"

FAIL_COUNT=0
LAST_STATE=""

check_socks() {

    netstat -lnt 2>/dev/null | grep -q ":${SOCKS_PORT} "

}

check_internet() {

    curl \
    --connect-timeout 5 \
    --max-time 10 \
    --socks5-hostname "127.0.0.1:${SOCKS_PORT}" \
    http://clients3.google.com/generate_204 \
    -o /dev/null \
    2>/dev/null

}

reconnect() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "<span style=\"color: orange\">[WATCHDOG] Reconnecting...</span>"

    "${LIBERNET_DIR}/bin/service.sh" -cl

    sleep 5

    "${LIBERNET_DIR}/bin/service.sh" -sl

}

loop() {

    while true; do

        if ! check_socks; then

            FAIL_COUNT=$((FAIL_COUNT+1))

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color: red\">[WATCHDOG] SOCKS missing (${FAIL_COUNT}/5)</span>"

        else

            if check_internet; then

                FAIL_COUNT=0

                if [ "$LAST_STATE" != "UP" ]; then

                    "${LIBERNET_DIR}/bin/log.sh" \
                    -w "<span style=\"color: green\">[WATCHDOG] Tunnel Healthy</span>"

                    LAST_STATE="UP"

                fi

            else

                FAIL_COUNT=$((FAIL_COUNT+1))

                if [ "$LAST_STATE" != "DOWN" ]; then

                    "${LIBERNET_DIR}/bin/log.sh" \
                    -w "<span style=\"color: red\">[WATCHDOG] Tunnel Lost</span>"

                    LAST_STATE="DOWN"

                fi

            fi

        fi

        if [ "$FAIL_COUNT" -ge 5 ]; then

            FAIL_COUNT=0

            reconnect

            sleep 20

        fi

        sleep 5

    done

}

run() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting ${SERVICE_NAME} service"

    screen -AmdS watchdog \
    "${LIBERNET_DIR}/bin/watchdog.sh" -l

}

stop() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Stopping ${SERVICE_NAME} service"

    kill $(screen -list | grep watchdog | awk -F '[.]' '{print $1}') \
    >/dev/null 2>&1

}

usage() {

cat <<EOF
Usage:

-r  Run watchdog
-s  Stop watchdog

EOF

}

case "$1" in

-r)
    run
    ;;

-s)
    stop
    ;;

-l)
    loop
    ;;

*)
    usage
    ;;

esac