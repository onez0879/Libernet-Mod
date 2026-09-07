#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

SERVICE_NAME="PING Loop"

get_server_host() {

    CONFIG="${LIBERNET_DIR}/system/config.json"

    MODE=$(jq -r '.tunnel.mode' "$CONFIG")

    case "$MODE" in
        0)
            PROFILE=$(jq -r '.tunnel.profile.ssh' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/ssh/${PROFILE}.json"
            ;;
        1)
            PROFILE=$(jq -r '.tunnel.profile.v2ray' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/v2ray/${PROFILE}.json"
            ;;
        2)
            PROFILE=$(jq -r '.tunnel.profile.ssh_ssl' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/ssh_ssl/${PROFILE}.json"
            ;;
        3)
            PROFILE=$(jq -r '.tunnel.profile.trojan' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/trojan/${PROFILE}.json"
            ;;
        4)
            PROFILE=$(jq -r '.tunnel.profile.shadowsocks' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/shadowsocks/${PROFILE}.json"
            ;;
        5)
            PROFILE=$(jq -r '.tunnel.profile.openvpn' "$CONFIG")
            FILE="${LIBERNET_DIR}/bin/config/openvpn/${PROFILE}.json"
            ;;
        *)
            echo ""
            return
            ;;
    esac

    jq -r '.ip // .host // empty' "$FILE" 2>/dev/null
}
check_server() {

    echo | nc "$HOST" 22 2>/dev/null | grep -q "SSH-"

}
loop() {

    HOST="$(get_server_host)"

    LAST_STATE=""
    COUNTER=0
    LOG_COUNTER=0

    while true; do

        LOG_COUNTER=$((LOG_COUNTER + 1))

        # refresh host tiap 30 detik
        if [ "$LOG_COUNTER" -ge 30 ]; then

            LOG_COUNTER=0

            HOST="$(get_server_host)"

            LOG="/root/libernet/log/mihomo.log"

            if [ -f "$LOG" ]; then

                SIZE=$(stat -c%s "$LOG" 2>/dev/null)

                [ "$SIZE" -ge 524288 ] && : > "$LOG"

            fi

        fi

        # jika host kosong skip
        if [ -z "$HOST" ]; then

            sleep 5
            continue

        fi

        if check_server; then

            COUNTER=$((COUNTER + 1))

            if [ "$LAST_STATE" != "UP" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:green\">[PING] ${HOST} Ok..!!</span>"

                LAST_STATE="UP"

            fi

            if [ "$COUNTER" -ge 60 ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:green\">[PING] VPN Connected</span>"

                COUNTER=0

            fi

        else

            COUNTER=0

            if [ "$LAST_STATE" != "DOWN" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:red\">[PING] ${HOST} Failed..!!</span>"

                # kalau socks juga hilang ubah status jadi disconnected
                if ! netstat -lnt 2>/dev/null | grep -q ":1080 "; then

                    "${LIBERNET_DIR}/bin/log.sh" -s 0
                    "${LIBERNET_DIR}/bin/log.sh" -c 0

                fi

                LAST_STATE="DOWN"

            fi

        fi

        sleep 2

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

    kill $(screen -list | grep ping-loop | awk -F '[.]' '{print $1}') \
    >/dev/null 2>&1

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
        echo "Usage: $0 {-r|-s|-l}"
        ;;
esac