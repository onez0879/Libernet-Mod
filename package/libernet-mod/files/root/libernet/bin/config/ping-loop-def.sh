#!/bin/bash

# PING Loop Wrapper
# by Lutfa Ilham
# v1.0

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

SERVICE_NAME="PING loop"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
INTERVAL="1"
HOST="google.com"

function http_ping() {
  httping -qi "${INTERVAL}" -t "${INTERVAL}" "${HOST}"
}

loop() {

    LAST_STATE=""
    COUNTER=0

    while true; do

        httping -c 1 -t 5 "$HOST" >/dev/null 2>&1

        if [ "$?" = "0" ]; then

            COUNTER=$((COUNTER+1))

            if [ "$LAST_STATE" != "UP" ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
-w "<span style=\"color:green\">[PING] ${HOST} Ok..!!</span>"

                LAST_STATE="UP"
            fi

            if [ "$COUNTER" -ge 60 ]; then

                "${LIBERNET_DIR}/bin/log.sh" \
                -w "<span style=\"color: green\">[PING] Tunnel Alive</span>"

                COUNTER=0
            fi

        else

            COUNTER=0

            if [ "$LAST_STATE" != "DOWN" ]; then

                ""${LIBERNET_DIR}/bin/log.sh" \
-w "<span style=\"color:red\">[PING] ${HOST} Failed..!!</span>"

                LAST_STATE="DOWN"
            fi

        fi

        sleep 1

    done
}

function run() {
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"
  echo -e "Starting ${SERVICE_NAME} service ..."
  screen -AmdS ping-loop "${LIBERNET_DIR}/bin/ping-loop.sh" -l \
    && echo -e "${SERVICE_NAME} service started!"
}

function stop() {
  # write to service log
  "${LIBERNET_DIR}/bin/log.sh" -w "Stopping ${SERVICE_NAME} service"
  echo -e "Stopping ${SERVICE_NAME} service ..."
  kill $(screen -list | grep ping-loop | awk -F '[.]' {'print $1'}) > /dev/null 2>&1
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
