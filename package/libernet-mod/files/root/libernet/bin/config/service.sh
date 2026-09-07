#!/bin/bash

# Libernet Service Wrapper
# by Lutfa Ilham
# v1.0

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"
TUNNEL_MODE="$(jq -r '.tunnel.mode' "${SYSTEM_CONFIG}")"
SOCKS_PORT="$(jq -r '.network.socks.port' "${SYSTEM_CONFIG}")"
PING_LOOP="$(jq -r '.settings.ping.enable' "${SYSTEM_CONFIG}")"
AUTO_RECON="$(jq -r '.settings.autoreconnect.enable' "${SYSTEM_CONFIG}")"
MEMORY_CLEANER="$(jq -r '.settings.memory.enable' "${SYSTEM_CONFIG}")"
DNS_RESOLVER="$(jq -r '.settings.dns.enable' "${SYSTEM_CONFIG}")"
AUTOSTART="$(jq -r '.tunnel.autostart' "${SYSTEM_CONFIG}")"
CONNECTED=false

log() {
    "${LIBERNET_DIR}/bin/log.sh" -w "$*"
}

status() {
    "${LIBERNET_DIR}/bin/log.sh" -s "$*"
}

connected() {
    "${LIBERNET_DIR}/bin/log.sh" -c "$*"
}

wait_wan() {
    local wan_if
    local wan_ip

    log "Waiting WAN..."

    while true; do
        wan_if=$(ip route | awk '/default/ {print $5}' | head -n1)

        if [ -z "${wan_if}" ]; then
            sleep 1
            continue
        fi

        wan_ip=$(ip -4 addr show "${wan_if}" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

        if [ -z "${wan_ip}" ]; then
            sleep 1
            continue
        fi

        WAN_IF="${wan_if}"
        WAN_IP="${wan_ip}"
        break
    done

    log "WAN Ready (${WAN_IF} - ${WAN_IP})"
    return 0
}

check_connection() {
    wait_wan || return 1

    wait_socks || {
        cancel_services
        return 1
    }

    test_socks || {
        cancel_services
        return 1
    }

    start_mihomo_tun || {
        cancel_services
        return 1
    }

    wait_mihomo || {
        "${LIBERNET_DIR}/bin/mihomo.sh" stop
        cancel_services
        return 1
    }

    mark_connected || {
        cancel_services
        return 1
    }

    log "Libernet ready."
    return 0
}

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

test_socks() {
    local check_url="https://clients3.google.com/generate_204"
    local retry=5

    log "Testing SOCKS..."

    while [ "${retry}" -gt 0 ]; do
        if curl --socks5-hostname "127.0.0.1:${SOCKS_PORT}" -s --connect-timeout 5 "${check_url}" >/dev/null 2>&1; then
            log "SOCKS Connected"
            return 0
        fi

        log "SOCKS not ready, retry..."
        retry=$((retry - 1))
        sleep 1
    done

    log '<span style="color:red">SOCKS Connection Failed</span>'
    return 1
}

check_qssh_connection() {
    local i

    log "[QSSH] Waiting worker..."

    for i in $(seq 1 20); do
        if netstat -lnt 2>/dev/null | grep -q ':1080 '; then
            return 0
        fi
        sleep 1
    done

    log "[QSSH] Worker timeout"
    return 1
}

memory_cleaner_service() {
    if [[ "${MEMORY_CLEANER}" == 'true' ]]; then
        "${LIBERNET_DIR}/bin/memory-cleaner.sh" -r
    fi
}

ping_loop_service() {
    if [[ "${PING_LOOP}" == 'true' ]]; then
        "${LIBERNET_DIR}/bin/ping-loop.sh" -r
    fi
}

auto_recon_service() {
    if [[ "${AUTO_RECON}" == 'true' ]]; then
        "${LIBERNET_DIR}/bin/auto_recon.sh" -r
    fi
}

mark_connected() {
    local end_time
    local connected_time
    local tmp_isp="/tmp/libernet_isp.tmp"

    end_time=$(date +%s)
    connected_time=$((end_time - START_TIME))

    connected "${end_time}"
    CONNECTED=true
    log "<span style=\"color:blue\">Libernet Connected in ${connected_time}s</span>"

    curl --socks5-hostname "127.0.0.1:${SOCKS_PORT}" -s http://ip-api.com/json |
        jq -r '"\(.country), \(.isp) (\(.as))"' > "${tmp_isp}"

    mv -f "${tmp_isp}" /tmp/libernet_isp
    return 0
}

wait_before_route() {
    local i

    log "Waiting before apply route..."

    for i in $(seq 1 20); do
        pidof q-load >/dev/null 2>&1 || return 1

        if netstat -lnt 2>/dev/null | grep -q ":${MIXED_PORT} "; then
            sleep 2
            return 0
        fi

        sleep 1
    done

    log "Route wait timeout"
    return 1
}

wait_mihomo() {
    local i
    local stable=0

    log "Waiting Mihomo..."

    for i in $(seq 1 20); do
        if curl -s --max-time 2 http://127.0.0.1:9090/version >/dev/null 2>&1; then
            stable=$((stable + 1))

            if [ "${stable}" -ge 2 ]; then
                return 0
            fi
        else
            stable=0
        fi

        sleep 1
    done

    return 1
}

start_mihomo() {
    log "Starting Mihomo..."

    "${LIBERNET_DIR}/bin/mihomo.sh" start || {
        log '<span style="color:red">Mihomo failed</span>'
        return 1
    }

    wait_mihomo || return 1
    sleep 5

    log "Applying Route..."
    "${LIBERNET_DIR}/bin/route.sh" start || return 1

    log "Mihomo ready"
    return 0
}

start_mihomo_tun() {
    log "Starting Mihomo..."

    "${LIBERNET_DIR}/bin/mihomo-tun.sh" start || {
        log '<span style="color:red">Mihomo failed</span>'
        return 1
    }

    wait_mihomo || return 1

    log "Applying Route..."
    "${LIBERNET_DIR}/bin/route.sh" start || return 1

    log "Mihomo ready"
    return 0
}

wait_qload() {
    local i

    log "Starting Q-LOAD..."

    for i in $(seq 1 30); do
        if netstat -lnt 2>/dev/null | grep -q ':7777 '; then
            log "Q-LOAD Ready (127.0.0.1:7777)"
            return 0
        fi

        sleep 1
    done

    log "Q-LOAD timeout"
    return 1
}

ssh_service() {
    wait_wan || {
        log "WAN failed"
        return 1
    }

    "${LIBERNET_DIR}/bin/ssh.sh" -r || {
        stop_services
        return 1
    }

    wait_socks || {
        stop_services
        return 1
    }

    "${LIBERNET_DIR}/bin/qload.sh" -r || {
        stop_services
        return 1
    }

    start_mihomo || {
        stop_services
        return 1
    }

    mark_connected || {
        stop_services
        return 1
    }

    run_other_services
}

qssh_service() {
    wait_wan || {
        log "WAN failed"
        return 1
    }

    log "Starting QSSH..."

    "${LIBERNET_DIR}/bin/qssh.sh" -r || {
        log "QSSH failed"
        return 1
    }

    start_mihomo || {
        stop_services
        return 1
    }

    mark_connected || {
        stop_services
        return 1
    }

    run_other_services
}

v2ray_service() {
    wait_wan || {
        log "WAN failed"
        return 1
    }

    "${LIBERNET_DIR}/bin/v2ray.sh" -r || {
        stop_services
        return 1
    }

    wait_socks || {
        stop_services
        return 1
    }

    "${LIBERNET_DIR}/bin/qload.sh" -r || {
        stop_services -c
        return 1
    }

    start_mihomo_tun || {
        stop_services
        return 1
    }

    mark_connected || {
        stop_services
        return 1
    }

    run_other_services    
}

run_other_services() {
    [ "${CONNECTED}" = true ] || return

    sleep 5
    memory_cleaner_service
    ping_loop_service
    auto_recon_service
}

start_services() {
    rm -f /tmp/libernet.manual_stop
    "${LIBERNET_DIR}/bin/log.sh" -r
    "${LIBERNET_DIR}/bin/log.sh" -c "0"
    "${LIBERNET_DIR}/bin/log.sh" -s 1

    START_TIME=$(date +%s)
    log "Starting Libernet service"

    case "${TUNNEL_MODE}" in
        "0") ssh_service ;;
        "1") v2ray_service ;;
        "2") qssh_service ;;
    esac

    if ${CONNECTED}; then
        "${LIBERNET_DIR}/bin/log.sh" -s 2
    else
        "${LIBERNET_DIR}/bin/log.sh" -s 0
    fi
}

stop_services() {
    touch /tmp/libernet.manual_stop

    "${LIBERNET_DIR}/bin/log.sh" -s 3
    log "Stopping Libernet service"

    case "${TUNNEL_MODE}" in
        "0") "${LIBERNET_DIR}/bin/ssh.sh" -s ;;
        "1") "${LIBERNET_DIR}/bin/v2ray.sh" -s ;;
        "2") "${LIBERNET_DIR}/bin/qssh.sh" -s ;;
    esac
    
   "${LIBERNET_DIR}/bin/qload.sh" -s

    if [[ "${1}" != '-c' ]]; then
        "${LIBERNET_DIR}/bin/memory-cleaner.sh" -s
        "${LIBERNET_DIR}/bin/ping-loop.sh" -s
        "${LIBERNET_DIR}/bin/auto_recon.sh" -s
    fi

    "${LIBERNET_DIR}/bin/route.sh" stop
    "${LIBERNET_DIR}/bin/route-qssh.sh" stop
    log "Removing Mihomo redirect rule"
    "${LIBERNET_DIR}/bin/mihomo.sh" stop
    log '<span style="color: red">Libernet service stopped</span>'
    echo -e "Libernet services stoped!"
    sleep 5
    "${LIBERNET_DIR}/bin/log.sh" -s 0
}

cancel_services() {
    stop_services -c
    sleep 5
    killall service.sh
}

auto_start() {
    while true; do
        usbmode -s >/dev/null 2>&1 &
        "${LIBERNET_DIR}/bin/log.sh" -ra

        if ip route show | grep -q default; then
            start_services
            break
        fi

        echo -e "Waiting available connection, try again"
        sleep 3
    done
}

enable_auto_start() {
    echo -e "Enable Libernet auto start ..."
    sed -i "/service.sh -as/d" /etc/rc.local
    sed -i "s/exit 0/$(echo "export LIBERNET_DIR=\"${LIBERNET_DIR}\" \&\& screen -AmdS libernet ${LIBERNET_DIR}/bin/service.sh -as" | sed 's/\//\\\//g')\nexit 0/g" /etc/rc.local &&
        echo -e "Libernet auto start enabled!"
}

disable_auto_start() {
    echo -e "Disable Libernet auto start ..."
    sed -i "/service.sh -as/d" /etc/rc.local &&
        echo -e "Libernet auto start disabled!"
}

case "${1}" in
    -c) check_connection ;;
    -sh) ssh_service ;;
    -sv) v2ray_service ;;
    -qs) qssh_service ;;
    -sl) start_services ;;
    -ds) stop_services ;;
    -dr) stop_services -c ;;
    -cl) cancel_services ;;
    -ea) enable_auto_start ;;
    -da) disable_auto_start ;;
    -as) auto_start ;;
esac
