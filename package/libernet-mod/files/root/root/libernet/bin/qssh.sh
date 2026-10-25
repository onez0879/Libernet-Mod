#!/bin/sh

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

LIBERNET_DIR="${LIBERNET_DIR:-/root/libernet}"

SERVICE_NAME="QSSH"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

QSSH_PROFILE="$(jq -r '.tunnel.profile.qssh // empty' "$SYSTEM_CONFIG")"
QSSH_CONFIG="${LIBERNET_DIR}/bin/config/qssh/${QSSH_PROFILE}.json"

SOCKS_PORT="$(jq -r '.concurrency.start_port // 1080' "$QSSH_CONFIG")"
WORKERS="$(jq -r '.concurrency.workers // 1' "$QSSH_CONFIG")"
QLOAD_PORT="$(jq -r '.network.qload.port // 7777' "$SYSTEM_CONFIG")"

wait_socks() {
    local timeout=30
    local count=0
    local start_port="${1:-1080}"
    local end_port="${2:-1083}"
    local port

    log "Waiting SOCKS..."

    while [ "${count}" -lt "${timeout}" ]; do
        for port in $(seq "${start_port}" "${end_port}"); do
            if port_listening "${port}"; then
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

port_listening() {
    local port_dec="$1"
    local port_hex
    port_hex=$(printf '%04X' "${port_dec}" 2>/dev/null) || return 1

    if [ -f /proc/net/tcp ] && grep -qiE ":${port_hex} .* 0A " /proc/net/tcp; then
        return 0
    fi
    if [ -f /proc/net/tcp6 ] && grep -qiE ":${port_hex} .* 0A " /proc/net/tcp6; then
        return 0
    fi

    if command -v ss >/dev/null 2>&1; then
        ss -lnt 2>/dev/null | grep -q ":${port_dec} " && return 0
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -lnt 2>/dev/null | grep -q ":${port_dec} " && return 0
    fi

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

    nohup "${LIBERNET_DIR}/core/qload" \
        -lport "${QLOAD_PORT}" \
        -tunnel ${TUNNELS} \
        >/tmp/qload.log 2>&1 &

    sleep 1

    if ! pidof qload >/dev/null 2>&1; then

        "${LIBERNET_DIR}/bin/log.sh" \
        -w "Failed to start Q-LOAD"

        killall qssh 2>/dev/null
        killall qload 2>/dev/null

        return 1

    fi

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "${SERVICE_NAME} service started"

    return 0
}

stop() {

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Stopping ${SERVICE_NAME} service"

    # Kill by name. killall may be absent on minimal builds: fall back
    # to pidof+kill so a missing tool cannot silently neuter the stop.
    # The old unbounded wait below hung stop forever when a kill
    # missed, so the sweep + lock release never ran.
    if command -v killall >/dev/null 2>&1; then
        killall qload 2>/dev/null
        killall qssh 2>/dev/null
    else
        kill $(pidof qload qssh 2>/dev/null) 2>/dev/null
    fi

    for _i in $(seq 1 10); do
        pidof qload >/dev/null || pidof qssh >/dev/null || break
        sleep 1
    done
    if command -v killall >/dev/null 2>&1; then
        killall -9 qload 2>/dev/null
        killall -9 qssh 2>/dev/null
    else
        kill -9 $(pidof qload qssh 2>/dev/null) 2>/dev/null
    fi

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "${SERVICE_NAME} service stopped"

}

status() {

    READY=0

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((SOCKS_PORT+i))

        if port_listening "${PORT}"; then
            READY=$((READY+1))
        fi

    done

    if ! port_listening "${QLOAD_PORT}"; then
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
