#!/bin/sh

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

SERVICE_NAME="QSSH"
LIBERNET_DIR="/root/libernet"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

QSSH_PROFILE="$(jq -r '.tunnel.profile.qssh' "$SYSTEM_CONFIG")"
QSSH_CONFIG="${LIBERNET_DIR}/bin/config/qssh/${QSSH_PROFILE}.json"

SOCKS_PORT="$(jq -r '.concurrency.start_port' "$QSSH_CONFIG")"
WORKERS="$(jq -r '.concurrency.workers' "$QSSH_CONFIG")"
QLOAD_PORT="$(jq -r '.network.qload.port' "$SYSTEM_CONFIG")"

wait_socks() {
    local timeout=30
    local count=0
    local start_port="${1:-1080}"
    local end_port="${2:-1083}"
    local port

    log "Waiting SOCKS..."

    while [ "${count}" -lt "${timeout}" ]; do
        for port in $(seq "${start_port}" "${end_port}"); do
            if netstat -lnt 2>/dev/null | grep -q ":${port} "; then
                SOCKS_PORT="${port}"
                log "SOCKS Ready (127.0.0.1:${SOCKS_PORT})"
                return 0
            fi
        done

        count=$((count + 1))
        sleep 1
    done

    log '<span style="color:red">SOCKS timeout</span>'
    return 1
}


run() {

    "${LIBERNET_DIR}/bin/log.sh" -w "Config: ${QSSH_PROFILE}, Mode: ${SERVICE_NAME}"
    "${LIBERNET_DIR}/bin/log.sh" -w "Starting ${SERVICE_NAME} service"

    : >/tmp/qssh.log
    : >/tmp/qload.log

    # Start Q-SSH-WORKER
    nohup "${LIBERNET_DIR}/core/qssh" \
        --dial "${QSSH_CONFIG}" \
        >/tmp/qssh.log 2>&1 &

    sleep 1

    if ! pidof qssh >/dev/null 2>&1; then
    
        "${LIBERNET_DIR}/bin/log.sh" \
        -w "Failed to start Q-SSH-WORKER"
    
        return 1
    
    fi
    
    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Q-SSH-WORKER started"
    sleep 3
    #wait_socks || return 1

    TUNNELS=""

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((SOCKS_PORT+i))
        TUNNELS="${TUNNELS} 127.0.0.1:${PORT}"
        
    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting Q-LOAD (${WORKERS} tunnels)"

    nohup "${LIBERNET_DIR}/core/q-load" \
        -lport "${QLOAD_PORT}" \
        -tunnel ${TUNNELS} \
        >/tmp/qload.log 2>&1 &

    sleep 1

    if ! pidof q-load >/dev/null 2>&1; then

        "${LIBERNET_DIR}/bin/log.sh" \
        -w "Failed to start Q-LOAD"

        killall qssh 2>/dev/null

        return 1

    fi

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "${SERVICE_NAME} service started"

    return 0
}

stop() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Stopping ${SERVICE_NAME} service"

    killall q-load 2>/dev/null
    killall qssh 2>/dev/null

    while pidof q-load >/dev/null || pidof qssh >/dev/null; do
        sleep 1
    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "${SERVICE_NAME} service stopped"

}

status() {

    READY=0

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((SOCKS_PORT+i))

        if netstat -lnt 2>/dev/null | grep -q ":${PORT} "; then
            READY=$((READY+1))
        fi

    done

    if ! netstat -lnt 2>/dev/null | grep -q ":${QLOAD_PORT} "; then
        echo "STOPPED"
        return 1
    fi

    if [ "$READY" -ne "$WORKERS" ]; then
        echo "STOPPED"
        return 1
    fi

    echo "RUNNING"
    return 0
}

restart() {

    stop

    sleep 2

    run

}
usage() {

cat <<EOF
Usage:
  -r  Run ${SERVICE_NAME} service
  -s  Stop ${SERVICE_NAME} service
  -R  Restart ${SERVICE_NAME} service
  -t  Check ${SERVICE_NAME} service status
EOF

}

case "$1" in
-r)
    run
;;
-s)
    stop
;;
-R)
    restart
;;
-t)
    status
;;
*)
    usage
;;
esac