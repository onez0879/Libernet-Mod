#!/bin/bash

# Libernet Service Wrapper
# by Lutfa Ilham
# v1.0

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Default to the standard install location when invoked without
# LIBERNET_DIR exported (e.g. manual run from a root shell).
LIBERNET_DIR="${LIBERNET_DIR:-/root/libernet}"

SYSTEM_CONFIG="${LIBERNET_DIR}/system/config.json"

# Self-heal: ensure all scripts are executable regardless of how IPK was built.
chmod +x "${LIBERNET_DIR}/bin/"*.sh 2>/dev/null

# Register PHP-CGI with uhttpd if not already present.
if command -v uci >/dev/null 2>&1; then
    PHP_REG=$(uci get uhttpd.main.interpreter 2>/dev/null || true)
    if ! echo "${PHP_REG}" | grep -q '\.php=/usr/bin/php-cgi'; then
        uci add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi' 2>/dev/null
        uci commit uhttpd 2>/dev/null
        /etc/init.d/uhttpd reload 2>/dev/null
    fi
fi

# First-run safety: seed config.json from the shipped default template
# so jq never reads a missing file.
if [ ! -f "${SYSTEM_CONFIG}" ] && [ -f "${LIBERNET_DIR}/system/config.default.json" ]; then
    cp "${LIBERNET_DIR}/system/config.default.json" "${SYSTEM_CONFIG}"
    chmod 600 "${SYSTEM_CONFIG}"
    echo "seeded ${SYSTEM_CONFIG} from default"
fi

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

# Port-listen check with no hard dependency on net-tools.
# Reads /proc/net/tcp{,6} directly; falls back to ss/netstat when present.
port_listening() {
    local port_dec="$1"
    local port_hex
    port_hex=$(printf '%04X' "${port_dec}" 2>/dev/null) || return 1

    # 0A = TCP_LISTEN in /proc/net/tcp state column
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

    "${LIBERNET_DIR}/bin/qload.sh" -r || {
        cancel_services
        return 1
    }

    wait_qload || {
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
    # Timeout bisa dioper sebagai argumen ke-3 (default 30 detik). Mode SSH
    # butuh jendela lebih panjang: origin-nya flaky (502 + putus di tengah
    # jalan), worker baru nyangkut kalau dikasih waktu retry lebih lama.
    local timeout="${3:-30}"
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
        if port_listening 1080; then
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
        pidof qload >/dev/null 2>&1 || return 1

        if port_listening "${MIXED_PORT:-7890}"; then
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
        if port_listening 7777; then
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
        stop_services -f
        return 1
    }

    # Jendela 120 detik untuk SSH: worker retry tiap 3 detik, jadi puluhan
    # percobaan sempat lewat sebelum dinyatakan gagal (origin flaky).
    wait_socks 1080 1083 120 || {
        stop_services -f
        return 1
    }

    "${LIBERNET_DIR}/bin/qload.sh" -r || {
        stop_services -f
        return 1
    }

    start_mihomo || {
        stop_services -f
        return 1
    }

    mark_connected || {
        stop_services -f
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
        stop_services -f
        return 1
    }

    start_mihomo || {
        stop_services -f
        return 1
    }

    mark_connected || {
        stop_services -f
        return 1
    }

    run_other_services
}

v2ray_service() {
    "${LIBERNET_DIR}/bin/v2ray.sh" -r
    check_connection
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
    acquire_lock || return 1
    rm -f /tmp/libernet.manual_stop
    "${LIBERNET_DIR}/bin/log.sh" -r
    "${LIBERNET_DIR}/bin/log.sh" -c "0"
    "${LIBERNET_DIR}/bin/log.sh" -s 1

    START_TIME=$(date +%s)
    log "Starting Libernet service"

    # Bersihkan sisa proses dari sesi sebelumnya (gagal start / crash /
    # stop yang tidak tuntas) supaya tidak ada konflik port saat start.
    sweep_stale_processes

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

# Cegah start/stop berjalan bersamaan (klik ganda, tombol restart,
# auto_recon): proses kedua MENUNGGU (maks 60 detik) sampai proses pertama
# selesai, bukan ikut jalan dan saling bunuh. Cancel (-c) tidak menunggu:
# ia memaksa berhenti dan memecahkan kunci. Kunci yatim (pemilik sudah
# mati, mis. proses di-kill) langsung diambil alih. Kunci milik proses
# sendiri (panggilan bersarang, mis. stop dari jalur gagal saat start)
# langsung lolos.
acquire_lock() {
    local lockdir="/tmp/libernet.lock"
    local waited=0
    local owner
    while true; do
        if mkdir "$lockdir" 2>/dev/null; then
            echo "$$" > "$lockdir/pid"
            trap 'rm -rf /tmp/libernet.lock' EXIT
            return 0
        fi
        owner=$(cat "$lockdir/pid" 2>/dev/null)
        if [ "$owner" = "$$" ]; then
            return 0
        fi
        if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then
            rm -rf "$lockdir"
            continue
        fi
        if [ "$waited" -ge 60 ]; then
            log "Libernet busy (start/stop masih berjalan), batal"
            return 1
        fi
        waited=$((waited + 1))
        sleep 1
    done
}

# Matikan SEMUA proses Libernet (v2ray, qload, mihomo, qssh + screen
# pendampingnya), apa pun modenya. Dipakai saat stop (sapu bersih akhir)
# dan saat start (bersihkan sisa sesi lama). Tidak menyentuh screen
# "libernet" (supervisor service.sh sendiri) maupun proses non-Libernet.
sweep_stale_processes() {
    # Named kills. killall may be absent on minimal builds: fall back
    # to pidof+kill so a missing tool cannot silently neuter the sweep.
    if command -v killall >/dev/null 2>&1; then
        killall v2ray qload mihomo qssh 2>/dev/null || true
    else
        kill $(pidof v2ray qload mihomo qssh 2>/dev/null) 2>/dev/null || true
    fi
    screen -S v2ray-client -X quit >/dev/null 2>&1 || true
    screen -S ping-loop -X quit >/dev/null 2>&1 || true

    for _i in $(seq 1 10); do
        pidof v2ray >/dev/null || pidof qload >/dev/null || \
        pidof mihomo >/dev/null || pidof qssh >/dev/null || break
        sleep 1
    done
    if command -v killall >/dev/null 2>&1; then
        killall -9 v2ray qload mihomo qssh 2>/dev/null || true
    else
        kill -9 $(pidof v2ray qload mihomo qssh 2>/dev/null) 2>/dev/null || true
    fi

    # Port-holder cleanup: whatever still listens on a Libernet SOCKS
    # port after the named kills is a leftover (e.g. orphan ssh clients
    # from SSH mode, which no name-based kill covers). Kill by PID.
    # This is what makes "stop = clean" hold for every mode.
    for _port in 1080 1081 1082 1083; do
        _pids=$(netstat -tlnp 2>/dev/null | awk -v addr="127.0.0.1:${_port}" '$4 == addr {split($NF, a, "/"); print a[1]}' | sort -u)
        [ -n "$_pids" ] && kill $_pids 2>/dev/null
    done
    sleep 2
    for _port in 1080 1081 1082 1083; do
        _pids=$(netstat -tlnp 2>/dev/null | awk -v addr="127.0.0.1:${_port}" '$4 == addr {split($NF, a, "/"); print a[1]}' | sort -u)
        [ -n "$_pids" ] && kill -9 $_pids 2>/dev/null
    done

    # Loud verification: a dirty stop must be visible, not silent.
    _left=$(pidof v2ray qload mihomo qssh 2>/dev/null)
    _ports=$(netstat -tlnp 2>/dev/null | grep -E '127.0.0.1:108[0-3] ' || true)
    if [ -n "$_left" ] || [ -n "$_ports" ]; then
        log "WARNING: leftover after sweep: PIDs=${_left} ports: ${_ports}"
    fi
}

stop_services() {
    # Kapan log dibersihkan: HANYA stop manual (-ds). Jalur cancel (-c)
    # dan bersih-bersih gagal (-f) TIDAK memotong log, supaya bukti
    # kenapa start gagal tetap bisa dibaca.
    local clear_logs=0
    case "${1}" in
        -c)
            # Cancel = paksa berhenti: pecahkan kunci apa pun, jangan menunggu.
            rm -rf /tmp/libernet.lock
            ;;
        -f)
            # Bersih-bersih dari jalur gagal (dipanggil proses start yang
            # sudah memegang kunci): lanjut tanpa kunci baru, tanpa potong log.
            ;;
        *)
            clear_logs=1
            acquire_lock || return 1
            ;;
    esac
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

    # Sapu bersih terakhir: jaminan "stop = semua service mati",
    # apapun modenya dan apapun yang terlewat skrip per-mode di atas.
    sweep_stale_processes

    log '<span style="color: red">Libernet service stopped</span>'
    echo -e "Libernet services stoped!"
    sleep 5

    # Kosongkan semua log setelah stop MANUAL: saat start berikutnya,
    # semua yang tampil di panel adalah log baru. Semua service sudah
    # mati di titik ini, jadi tidak ada yang menulis lagi setelah
    # pemotongan. (Jalur -c/-f sengaja tidak memotong: bukti gagal
    # start harus tetap terbaca.)
    if [ "$clear_logs" = 1 ]; then
        : > "${LIBERNET_DIR}/log/service.log"
        : > "${LIBERNET_DIR}/log/clash.log"
        : > /tmp/v2ray.log
        : > /tmp/qload.log
        : > /tmp/qssh.log
    fi

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
