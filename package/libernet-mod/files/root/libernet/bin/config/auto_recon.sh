#!/bin/bash

# ==========================================================
# Libernet Auto Reconnect
# Optimized for SSH / V2Ray / QSSH
# ==========================================================

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

SERVICE_NAME="Auto Reconnect"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
log() {
    "${LIBERNET_DIR}/bin/log.sh" -w "$*"
}

reload_config() {

    TUNNEL_MODE="$(jq -r '.tunnel.mode' "$SYSTEM_CONFIG")"
    QLOAD_PORT="$(jq -r '.network.qload.port' "$SYSTEM_CONFIG")"
    AUTO_SWITCH="$(jq -r '.settings.autoswitch.enable' "$SYSTEM_CONFIG")"

}

reload_config

check_socks() {

    curl \
        --connect-timeout 5 \
        --max-time 10 \
        --socks5-hostname 127.0.0.1:${QLOAD_PORT} \
        http://clients3.google.com/generate_204 \
        -o /dev/null 2>&1

}

switch_config() {

    TRY=0
    MAX_TRY=5

    while [ "$TRY" -lt "$MAX_TRY" ]; do

        TRY=$((TRY+1))

        "${LIBERNET_DIR}/bin/config-switch.sh"

        reload_config

        "${LIBERNET_DIR}/bin/service.sh" -sl

        "${LIBERNET_DIR}/bin/log.sh" \
        -w "<span style=\"color:orange\">[AUTO-RC] Testing Config (${TRY}/${MAX_TRY})</span>"

        sleep 20

        if check_socks; then

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:green\">[AUTO-RC] Config OK</span>"

            return 0

        fi

        "${LIBERNET_DIR}/bin/log.sh" \
        -w "<span style=\"color:red\">[AUTO-RC] Config Failed</span>"

        "${LIBERNET_DIR}/bin/service.sh" -dr

        sleep 2

    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "<span style=\"color:red\">[AUTO-RC] All Config Failed</span>"

    return 1

}

recon() {

    reload_config

    WAIT=0
    MAX_WAIT=30
    START=$(date +%s)

    log "[AUTO-RC] Waiting Auto Reconnect..."

    while [ "$WAIT" -lt "$MAX_WAIT" ]; do

        if check_socks; then

            ELAPSED=$(( $(date +%s) - START ))

            log "[AUTO-RC] Connection Restored (${ELAPSED}s)"

            return 0

        fi

        sleep 1

        WAIT=$((WAIT+1))

    done

    log "[AUTO-RC] Auto Reconnect Timeout (${MAX_WAIT}s)"

    if [ "$AUTO_SWITCH" = "true" ]; then

        log "[AUTO-RC] Auto Switch Config..."

        switch_config

    fi

}

loop() {

    FAIL_COUNT=0

    while true; do

        reload_config

        if [ -f /tmp/libernet.manual_stop ]; then

            FAIL_COUNT=0

            sleep 3

            continue

        fi

        if ! netstat -lnt 2>/dev/null | grep -q ":${QLOAD_PORT} "; then

            FAIL_COUNT=$((FAIL_COUNT+1))

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:red\">[AUTO-RC] SOCKS Missing (${FAIL_COUNT}/3)</span>"

        elif ! check_socks; then

            FAIL_COUNT=$((FAIL_COUNT+1))

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:red\">[AUTO-RC] SOCKS Timeout (${FAIL_COUNT}/3)</span>"

        else

            FAIL_COUNT=0

        fi

        if [ "$FAIL_COUNT" -ge 3 ]; then

            FAIL_COUNT=0

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:orange\">[AUTO-RC] Connection Lost</span>"

            recon

            sleep 15

        fi

        sleep 5

    done

}

run() {

    if pgrep -f "auto_recon.sh -l" >/dev/null; then
        return 0
    fi

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting ${SERVICE_NAME} service"

    screen -AmdS auto-recon \
        "${LIBERNET_DIR}/bin/auto_recon.sh" -l

}

stop() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Stopping ${SERVICE_NAME} service"

    kill $(screen -list | awk '/auto-recon/ {print $1}' | cut -d. -f1) \
        >/dev/null 2>&1

    pkill -f "auto_recon.sh -l" >/dev/null 2>&1

}

usage() {

cat <<EOF
Usage:
    -r    Run ${SERVICE_NAME}
    -s    Stop ${SERVICE_NAME}
    -l    Loop (Internal)
EOF

}

case "${1}" in

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