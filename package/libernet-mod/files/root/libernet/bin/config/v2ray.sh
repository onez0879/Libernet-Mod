#!/bin/bash

# V2Ray Wrapper
# by Lutfa Ilham
# v1.0.0

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

SERVICE_NAME="V2Ray"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
V2RAY_PROFILE="$(grep 'v2ray":' ${SYSTEM_CONFIG} | awk '{print $2}' | sed 's/,//g; s/"//g')"
V2RAY_CONFIG="${LIBERNET_DIR}/bin/config/v2ray/${V2RAY_PROFILE}.json"
V2RAY_PROTOCOL="$(grep 'protocol":' ${V2RAY_CONFIG} | awk '{print $2}' | sed 's/,//g; s/"//g' | tail -n1)"

function run() {
  case "${V2RAY_PROTOCOL}" in
    "vmess")
      V2RAY_PROTOCOL="VMess"
      ;;
    "vless")
      V2RAY_PROTOCOL="VLESS"
      ;;
    "trojan")
      V2RAY_PROTOCOL="Trojan"
      ;;
  esac
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Config: ${V2RAY_PROFILE}, Mode: ${SERVICE_NAME}, Protocol: ${V2RAY_PROTOCOL}"
  "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"
  echo -e "Starting ${SERVICE_NAME} service ..."
  WAN_IP=$(ip -4 route get 8.8.8.8 2>/dev/null \
    | awk '/src/ {
        for(i=1;i<=NF;i++)
            if($i=="src")
                print $(i+1)
    }' | head -n1)

[ -z "$WAN_IP" ] && WAN_IP="0.0.0.0"

sed -i -E 's/"sendThrough":[[:space:]]*"[^"]*"/"sendThrough": "'"$WAN_IP"'"/' "${V2RAY_CONFIG}"
  screen -AmdS v2ray-client bash -c "while true; do v2ray run -config \"${V2RAY_CONFIG}\" >> /tmp/v2ray.log 2>&1 sleep 3; done" \
    && echo -e "${SERVICE_NAME} service started!"
}

function stop() {

    "${LIBERNET_DIR}/bin/log.sh" -w "Stopping ${SERVICE_NAME} service"

    screen -list | grep -q v2ray-client && \
        kill $(screen -list | grep v2ray-client | awk -F '[.]' '{print $1}')

    killall v2ray >/dev/null 2>&1

    while screen -list | grep -q v2ray-client; do
        sleep 1
    done
    "${LIBERNET_DIR}/bin/log.sh" -w "${SERVICE_NAME} service stopped"
    screen -wipe >/dev/null 2>&1
}
reconnect() {

    stop

    # tunggu semua proses v2ray benar-benar mati
    for _ in $(seq 1 30); do

        pgrep -x v2ray >/dev/null || break

        sleep 1

    done

    # tunggu port SOCKS lepas
    for _ in $(seq 1 30); do

        if ! netstat -lnt 2>/dev/null | grep -q ":1080 "; then
            break
        fi

        sleep 1

    done

    run

}
function usage() {
  cat <<EOF
Usage:
  -r  Run ${SERVICE_NAME} service
  -s  Stop ${SERVICE_NAME} service
  -R  Reconnect ${SERVICE_NAME} service
EOF
}

case "${1}" in
  -r)
    run
    ;;

  -R)
    reconnect
    ;;

  -s)
    stop
    ;;

  *)
    usage
    ;;
esac
