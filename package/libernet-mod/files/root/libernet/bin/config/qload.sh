#!/bin/bash


SERVICE_NAME="Q-LOAD"

LIBERNET_DIR="/root/libernet"

SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

TUNNEL_MODE="$(jq -r '.tunnel.mode' "$SYSTEM_CONFIG")"

case "$TUNNEL_MODE" in

    # SSH & QSSH sama-sama pakai config SSH
    0|2)

        SSH_PROFILE="$(jq -r '.tunnel.profile.ssh' "$SYSTEM_CONFIG")"
        PROFILE_CONFIG="${LIBERNET_DIR}/bin/config/ssh/${SSH_PROFILE}.json"

        ;;

    # V2Ray pakai config V2Ray
    1)

        V2RAY_PROFILE="$(jq -r '.tunnel.profile.v2ray' "$SYSTEM_CONFIG")"
        PROFILE_CONFIG="${LIBERNET_DIR}/bin/config/v2ray/${V2RAY_PROFILE}.json"

        ;;

    *)

        echo "Unknown tunnel mode: $TUNNEL_MODE"
        exit 1
        ;;

esac

QLOAD_PORT="$(jq -r '.network.qload.port' "$SYSTEM_CONFIG")"

WORKERS="$(jq -r '.concurrency.workers' "$PROFILE_CONFIG")"
START_PORT="$(jq -r '.concurrency.start_port' "$PROFILE_CONFIG")"

run() {

    TUNNELS=""

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((START_PORT+i))

        TUNNELS="${TUNNELS} 127.0.0.1:${PORT}"

    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting Q-LOAD (${WORKERS} tunnels)"

    killall q-load 2>/dev/null

    nohup "${LIBERNET_DIR}/core/q-load" \
        -lport "${QLOAD_PORT}" \
        -tunnel ${TUNNELS} \
        >/tmp/qload.log 2>&1 &

    sleep 3

    if ! pidof q-load >/dev/null; then

        "${LIBERNET_DIR}/bin/log.sh" \
            -w "Failed to start ${SERVICE_NAME}"

        return 1

    fi

    "${LIBERNET_DIR}/bin/log.sh" \
        -w "${SERVICE_NAME} listening on :${QLOAD_PORT}"

    return 0
}
stop() {

    "${LIBERNET_DIR}/bin/log.sh" -w "Stopping ${SERVICE_NAME}"

    killall q-load 2>/dev/null

    while pidof q-load >/dev/null; do
        sleep 1
    done

    #"${LIBERNET_DIR}/bin/log.sh" -w "${SERVICE_NAME} stopped"
}

status() {

    if netstat -lnt 2>/dev/null | grep -q ":${QLOAD_PORT} "; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

restart() {

    stop

    sleep 1

    run

}

usage() {

cat <<EOF
Usage:
  qload.sh -r <backend1> [backend2...]
  qload.sh -s
  qload.sh -R <backend1> [backend2...]
  qload.sh -t

Example:
  qload.sh -r 127.0.0.1:1080
  qload.sh -r 127.0.0.1:1080 127.0.0.1:1081
EOF

}

case "$1" in
-r)
    run "$@"
    ;;
-s)
    stop
    ;;
-R)
    shift
    restart "$@"
    ;;
-t)
    status
    ;;
*)
    usage
    ;;
esac