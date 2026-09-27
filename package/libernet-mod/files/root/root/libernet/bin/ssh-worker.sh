#!/bin/bash
# QSSH Worker (merged SSH + HTTP Proxy)
# by Lutfa Ilham

# This script merges the logic from:
# - ssh.sh
# - ssh-loop.sh
# - http.sh
# and keeps http.py as the Python injector.

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

SERVICE_NAME="SSH Worker"
LIBERNET_DIR="/root/libernet"
SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

log() {
    "${LIBERNET_DIR}/bin/log.sh" -w "$*"
}

# ------------------------------
# Config loader
# ------------------------------
ENABLE_WS_CDN="${ENABLE_WS_CDN:-}"

load_config() {
    if [ -n "$ENABLE_WS_CDN" ]; then
        SSH_PROFILE="$(jq -r '.tunnel.profile.ssh_ws_cdn // empty' "$SYSTEM_CONFIG")"
        SSH_CONFIG="${LIBERNET_DIR}/bin/config/ssh_ws_cdn/${SSH_PROFILE}.json"
    else
        SSH_PROFILE="$(jq -r '.tunnel.profile.ssh // empty' "$SYSTEM_CONFIG")"
        SSH_CONFIG="${LIBERNET_DIR}/bin/config/ssh/${SSH_PROFILE}.json"
    fi

    if [ -z "$SSH_PROFILE" ] || [ ! -f "$SSH_CONFIG" ]; then
        log "SSH profile not found or invalid: ${SSH_PROFILE}"
        exit 1
    fi

    SSH_HOST="$(jq -r '.host // empty' "$SSH_CONFIG")"
    SSH_PORT="$(jq -r '.port // empty' "$SSH_CONFIG")"
    SSH_USER="$(jq -r '.username // empty' "$SSH_CONFIG")"
    SSH_PASS="$(jq -r '.password // empty' "$SSH_CONFIG")"

    ENABLE_HTTP="$(jq -r '.enable_http // false' "$SSH_CONFIG")"
    HTTP_IP="$(jq -r '.http.ip // empty' "$SSH_CONFIG")"
    HTTP_PORT="$(jq -r '.http.port // empty' "$SSH_CONFIG")"

    WORKERS="$(jq -r '.concurrency.workers // 1' "$SSH_CONFIG")"
    START_PORT="$(jq -r '.concurrency.start_port // 1080' "$SSH_CONFIG")"

    QLOAD_PORT="$(jq -r '.network.qload.port // empty' "$SYSTEM_CONFIG")"

    if [ -z "$SSH_HOST" ] || [ -z "$SSH_PORT" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_PASS" ]; then
        log "SSH config is incomplete"
        exit 1
    fi

    if [ "$ENABLE_HTTP" = "true" ]; then
        if [ -z "$HTTP_IP" ] || [ -z "$HTTP_PORT" ]; then
            log "HTTP config is incomplete"
            exit 1
        fi
    fi
}

# ------------------------------
# HTTP proxy
# ------------------------------
http_session="http-proxy"

start_http() {
    [ "$ENABLE_HTTP" != "true" ] && return 0

    stop_http

    log "Starting HTTP Proxy service"

    screen -dmS "$http_session" bash -c "
        while true; do
            python3 -u \"${LIBERNET_DIR}/bin/http.py\" \"${SSH_CONFIG}\" -l \"${HTTP_PORT}\"
            sleep 3
        done
    "

    sleep 1
    return 0
}

stop_http() {
    screen -S "$http_session" -X quit >/dev/null 2>&1 || true
    return 0
}
set_status() {
    echo "$1" > "/tmp/ssh-${SOCKS_PORT}.status"
}
# ------------------------------
# SSH worker loop (self-contained)
# ------------------------------
ssh_worker() {
    SOCKS_PORT="$1"

    set_status() {
        echo "$1" > "/tmp/ssh-${SOCKS_PORT}.status"
    }

    while true; do

        set_status CONNECTING

        if [ "$ENABLE_HTTP" = "true" ]; then
            sshpass -p "$SSH_PASS" ssh \
                -4CND "$SOCKS_PORT" \
                -p "$SSH_PORT" \
                -o ProxyCommand="/usr/bin/corkscrew $HTTP_IP $HTTP_PORT %h %p" \
                -o ConnectTimeout=10 \
                -o ServerAliveInterval=10 \
                -o ServerAliveCountMax=2 \
                -o TCPKeepAlive=yes \
                -o ExitOnForwardFailure=yes \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PermitLocalCommand=yes \
                -o LocalCommand="echo CONNECTED >/tmp/ssh-${SOCKS_PORT}.status" \
                "$SSH_USER@$SSH_HOST"
        else
            sshpass -p "$SSH_PASS" ssh \
                -4CND "$SOCKS_PORT" \
                -p "$SSH_PORT" \
                -o ConnectTimeout=10 \
                -o ServerAliveInterval=10 \
                -o ServerAliveCountMax=2 \
                -o TCPKeepAlive=yes \
                -o ExitOnForwardFailure=yes \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PermitLocalCommand=yes \
                -o LocalCommand="echo CONNECTED >/tmp/ssh-${SOCKS_PORT}.status" \
                "$SSH_USER@$SSH_HOST"
        fi

        if [ $? -eq 255 ]; then
            set_status FAILED
        else
            set_status STOPPED
        fi

        sleep 3
    done
}
# ------------------------------
# Worker sessions
# ------------------------------
worker_session_name() {
    # $1 = 0-based worker index
    echo "ssh-worker-$(( $1 + 1 ))"
}

stop_worker_sessions() {
    i=0
    while [ "$i" -lt "$WORKERS" ]; do
        SESSION="$(worker_session_name "$i")"
        screen -S "$SESSION" -X quit >/dev/null 2>&1 || true
        i=$((i + 1))
    done
}

start_worker_sessions() {
    i=0
    while [ "$i" -lt "$WORKERS" ]; do
        PORT=$((START_PORT + i))
        SESSION="$(worker_session_name "$i")"

        log "Launching ${SESSION} on port ${PORT}"

        screen -dmS "$SESSION" \
            /bin/bash "$0" --worker "$PORT"

        i=$((i + 1))
    done
}

# ------------------------------
# Status
# ------------------------------
status() {
    READY=0
    i=0

    while [ "$i" -lt "$WORKERS" ]; do
        PORT=$((START_PORT + i))
        if netstat -lnt 2>/dev/null | grep -q ":${PORT} "; then
            READY=$((READY + 1))
        fi
        i=$((i + 1))
    done

    if [ "$READY" -eq "$WORKERS" ]; then
        echo "RUNNING"
        return 0
    fi

    echo "STOPPED"
    return 1
}

# ------------------------------
# Start / Stop
# ------------------------------
run() {
    load_config

    log "Config: ${SSH_PROFILE}, Mode: ${SERVICE_NAME}"

    if [ "$ENABLE_HTTP" = "true" ]; then
        start_http || return 1
    fi

    stop_worker_sessions
    log "Starting ${SERVICE_NAME} service"
    start_worker_sessions || return 1
    log "${SERVICE_NAME} service started"
}

stop() {
    load_config
    log "Stopping ${SERVICE_NAME} service"
    stop_worker_sessions
    stop_http
    log "${SERVICE_NAME} service stopped"
}

# ------------------------------
# Worker entrypoint
# ------------------------------
worker_main() {
    SOCKS_PORT="$1"

    load_config
    ssh_worker "$SOCKS_PORT"
}

usage() {
    cat <<EOF
Usage:
  $0 -r            Run ${SERVICE_NAME}
  $0 -s            Stop ${SERVICE_NAME}
  $0 -t            Check ${SERVICE_NAME} status
  $0 --worker PORT Run one worker (internal)
EOF
}

case "${1:-}" in
    -r)
        run
        ;;
    -s)
        stop
        ;;
    -t)
        status
        ;;
    --worker)
        shift
        [ -z "${1:-}" ] && { echo "Missing worker port"; exit 1; }
        worker_main "$1"
        ;;
    *)
        usage
        ;;
esac
