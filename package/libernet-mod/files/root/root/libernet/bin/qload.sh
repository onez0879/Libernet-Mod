SERVICE_NAME="Q-LOAD"

LIBERNET_DIR="/root/libernet"

SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

QLOAD_PORT="$(jq -r '.network.qload.port' "$SYSTEM_CONFIG")"

SSH_PROFILE="$(jq -r '.tunnel.profile.ssh' "$SYSTEM_CONFIG")"
SSH_CONFIG="${LIBERNET_DIR}/bin/config/ssh/${SSH_PROFILE}.json"

WORKERS="$(jq -r '.concurrency.workers' "$SSH_CONFIG")"
START_PORT="$(jq -r '.concurrency.start_port' "$SSH_CONFIG")"

run() {

    TUNNELS=""

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((START_PORT+i))

        TUNNELS="${TUNNELS} 127.0.0.1:${PORT}"

    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting Q-LOAD (${WORKERS} tunnels)"

    killall q-load 2>/dev/null

    nohup "${LIBERNET_DIR}/core/qload" \
        -lport "${QLOAD_PORT}" \
        -tunnel ${TUNNELS} \
        >/tmp/qload.log 2>&1 &

    sleep 1

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
