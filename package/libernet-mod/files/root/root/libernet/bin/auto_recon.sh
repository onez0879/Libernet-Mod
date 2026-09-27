#!/bin/bash

# PING Loop Wrapper
# by Lutfa Ilham
# v1.0

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

SERVICE_NAME="Auto Reconnect"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
TUNNEL_MODE="$(grep 'mode":' ${SYSTEM_CONFIG} | awk '{print $2}' | sed 's/,//g; s/"//g')"
QLOAD_PORT="$(jq -r '.tun2socks.socks.port' "$SYSTEM_CONFIG")"

check_socks() {

    curl \
    --connect-timeout 5 \
    --max-time 10 \
    --socks5-hostname 127.0.0.1:${QLOAD_PORT} \
    http://clients3.google.com/generate_204 \
    -o /dev/null 2>&1

}

function loop() {

    FAIL_COUNT=0

    while true; do

        if [ -f /tmp/libernet.manual_stop ]; then

            FAIL_COUNT=0

            sleep 5

            continue

        fi

        # SOCKS tidak listen
        if ! netstat -lnt 2>/dev/null | grep -q ":${QLOAD_PORT} "; then

            FAIL_COUNT=$((FAIL_COUNT+1))

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:red\">[AUTO-RC] SOCKS missing (${FAIL_COUNT}/3)</span>"

        # SOCKS listen tapi bengong
        elif ! check_socks; then

            FAIL_COUNT=$((FAIL_COUNT+1))

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:red\">[AUTO-RC] SOCKS timeout (${FAIL_COUNT}/3)</span>"

        else

            FAIL_COUNT=0

        fi
        
        if [ "$FAIL_COUNT" -ge 3 ]; then

            FAIL_COUNT=0

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:orange\">[AUTO-RC] Connection lost</span>"

            recon

            sleep 15

        fi

        sleep 5

    done

}
#stop libernet

recon() {

    SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
    TUNNEL_MODE="$(jq -r '.tunnel.mode' "$SYSTEM_CONFIG")"

    # QSSH
if [ "$TUNNEL_MODE" = "6" ]; then

    if ! "${LIBERNET_DIR}/bin/qssh.sh" -t >/dev/null; then

        "${LIBERNET_DIR}/bin/log.sh" \
        -w "<span style=\"color:orange\">[AUTO-RC] Restarting QSSH...</span>"

        "${LIBERNET_DIR}/bin/qssh.sh" -R

    fi

    return

fi

    AUTO_SWITCH=$(jq -r '.settings.autoswitch.enable' "$SYSTEM_CONFIG")

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "<span style=\"color:orange\">[AUTO-RC] Full Reconnect</span>"

    "${LIBERNET_DIR}/bin/service.sh" -dr

    sleep 2

    if [ "$AUTO_SWITCH" = "true" ]; then

        TRY=0
        MAX_TRY=5

        while [ "$TRY" -lt "$MAX_TRY" ]; do

            TRY=$((TRY+1))

            "${LIBERNET_DIR}/bin/config-switch.sh"

            "${LIBERNET_DIR}/bin/service.sh" -sl

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:orange\">[AUTO-RC] Testing Config (${TRY}/${MAX_TRY})</span>"

            sleep 20

            if netstat -lnt 2>/dev/null | grep -q ":1080 "; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color:green\">[AUTO-RC] Config OK</span>"

                return

            fi

            "${LIBERNET_DIR}/bin/log.sh" \
            -w "<span style=\"color:red\">[AUTO-RC] Config Failed</span>"

            "${LIBERNET_DIR}/bin/service.sh" -dr

            sleep 2

        done

    else

        "${LIBERNET_DIR}/bin/service.sh" -sl

    fi

}
function start_services() {
  # write to service log
  #"${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start Tunnel Service"
  case "${TUNNEL_MODE}" in
    "0")
	  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start SSH Service"
      "${LIBERNET_DIR}/bin/ssh.sh" -r
      ;;
    "1")
	  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start v2ray Service"
      "${LIBERNET_DIR}/bin/v2ray.sh" -r
      ;;
    "2")
	  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start SSH-SSL Service"
      "${LIBERNET_DIR}/bin/ssh-ssl.sh" -r
      ;;
    "3")
	  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start Trojan Service"
      "${LIBERNET_DIR}/bin/trojan.sh" -r
      ;;
    "4")
	  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Re-Start shadowsocks Service"
      "${LIBERNET_DIR}/bin/shadowsocks.sh" -r
      ;;
  esac
  sleep 10
  "${LIBERNET_DIR}/bin/log.sh" -w "<span style=\"color: blue\">[AUTO-RC]Checking...</span>"
}

function stop_services() {
  "${LIBERNET_DIR}/bin/log.sh" -w "[AUTO-RC]Stopping Tunnel Service"
  case "${TUNNEL_MODE}" in
    "0")
      "${LIBERNET_DIR}/bin/ssh.sh" -s
      ;;
    "1")
      "${LIBERNET_DIR}/bin/v2ray.sh" -s
      ;;
    "2")
      "${LIBERNET_DIR}/bin/ssh-ssl.sh" -s
      ;;
    "3")
      "${LIBERNET_DIR}/bin/trojan.sh" -s
      ;;
    "4")
      "${LIBERNET_DIR}/bin/shadowsocks.sh" -s
      ;;
    "5")
      "${LIBERNET_DIR}/bin/openvpn.sh" -s
      ;;
  esac

}

function run() {

  if pgrep -f "auto_recon.sh -l" >/dev/null; then
      return 0
  fi

  "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"

  screen -AmdS auto-recon \
  "${LIBERNET_DIR}/bin/auto_recon.sh" -l

}
function stop() {
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Stopping ${SERVICE_NAME} service"
  echo -e "Stopping ${SERVICE_NAME} service ..."
  # disableb led
  #hg680p.sh -lan dis &>/dev/null
  kill $(screen -list | grep auto-recon | awk -F '[.]' {'print $1'}) > /dev/null 2>&1
  echo -e "${SERVICE_NAME} service stopped!"
}

function usage() {
  cat <<EOF
Usage:
  -r  Run ${SERVICE_NAME} service
  -s  Stop ${SERVICE_NAME} service
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