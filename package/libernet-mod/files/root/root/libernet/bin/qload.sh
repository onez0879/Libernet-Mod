#!/bin/bash


SERVICE_NAME="Q-LOAD"

LIBERNET_DIR="${LIBERNET_DIR:-/root/libernet}"

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

        # Mode belum dikenali: fallback ke profil SSH, bukan exit buta
        SSH_PROFILE="$(jq -r '.tunnel.profile.ssh // empty' "$SYSTEM_CONFIG")"
        PROFILE_CONFIG="${LIBERNET_DIR}/bin/config/ssh/${SSH_PROFILE}.json"
        "${LIBERNET_DIR}/bin/log.sh" \
            -w "Q-LOAD: mode ${TUNNEL_MODE} belum dikenali, fallback ke profil SSH (${SSH_PROFILE})"
        if [ ! -f "$PROFILE_CONFIG" ]; then
            echo "Unknown tunnel mode: $TUNNEL_MODE (no fallback profile)" 1>&2
            exit 1
        fi
        ;;

esac

QLOAD_PORT="$(jq -r '.network.qload.port' "$SYSTEM_CONFIG")"

WORKERS="$(jq -r '.concurrency.workers // 1' "$PROFILE_CONFIG")"
START_PORT="$(jq -r '.concurrency.start_port // 1080' "$PROFILE_CONFIG")"

# guard: jq null/empty -> default aman
{ [ -z "$WORKERS" ] || [ "$WORKERS" = "null" ]; } && WORKERS=1
{ [ -z "$START_PORT" ] || [ "$START_PORT" = "null" ]; } && START_PORT=1080
{ [ -z "$QLOAD_PORT" ] || [ "$QLOAD_PORT" = "null" ]; } && QLOAD_PORT=7777

# port checker tanpa netstat (OpenWrt 24.10: net-tools deprecated)
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

    TUNNELS=""

    for i in $(seq 0 $((WORKERS-1))); do

        PORT=$((START_PORT+i))

        TUNNELS="${TUNNELS} 127.0.0.1:${PORT}"

    done

    "${LIBERNET_DIR}/bin/log.sh" \
    -w "Starting Q-LOAD (${WORKERS} tunnels)"

    killall qload 2>/dev/null

    nohup "${LIBERNET_DIR}/core/qload" \
        -lport "${QLOAD_PORT}" \
        -tunnel ${TUNNELS} \
        >/tmp/qload.log 2>&1 &

    sleep 3

    if ! pidof qload >/dev/null; then

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

    killall qload 2>/dev/null

    # Tunggu mati baik-baik (maks 10 detik), lalu paksa — jangan sampai
    # stop menggantung selamanya kalau ada proses yang menolak SIGTERM.
    for _i in $(seq 1 10); do
        pidof qload >/dev/null || break
        sleep 1
    done
    killall -9 qload 2>/dev/null || true

    #"${LIBERNET_DIR}/bin/log.sh" -w "${SERVICE_NAME} stopped"
}

status() {

    if port_listening "${QLOAD_PORT}"; then
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
