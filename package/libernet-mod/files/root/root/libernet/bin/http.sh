#!/bin/bash

# HTTP Proxy Wrapper
# by Lutfa Ilham
# v1.0.0

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

SERVICE_NAME="HTTP Proxy"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

if [ -n "$ENABLE_WS_CDN" ]; then
    SSH_PROFILE="$(jq -r '.tunnel.profile.ssh_ws_cdn' "$SYSTEM_CONFIG")"
    SSH_CONFIG="${LIBERNET_DIR}/bin/config/ssh_ws_cdn/${SSH_PROFILE}.json"
else
    SSH_PROFILE="$(jq -r '.tunnel.profile.ssh' "$SYSTEM_CONFIG")"
    SSH_CONFIG="${LIBERNET_DIR}/bin/config/ssh/${SSH_PROFILE}.json"
fi

LISTEN_PORT="$(jq -r '.http.port' "$SSH_CONFIG")"


function run() {
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"
  echo -e "Starting ${SERVICE_NAME} service ..."
  screen -AmdS http-proxy bash -c "while true; do python3 -u \"${LIBERNET_DIR}/bin/http.py\" \"${SSH_CONFIG}\" -l ${LISTEN_PORT}; sleep 3; done" \
    && echo -e "${SERVICE_NAME} service started!"
}

function stop() {
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Stopping ${SERVICE_NAME} service"
  echo -e "Stopping ${SERVICE_NAME} service ..."
  kill $(screen -list | grep http-proxy | awk -F '[.]' {'print $1'})
  killall python3
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
  *)
    usage
    ;;
esac
