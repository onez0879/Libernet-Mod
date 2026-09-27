#!/bin/sh
#=========================================================
# Libernet Routing Engine
# Forked from QTUN Routing Engine
#=========================================================

set -u

CONFIG="/root/libernet/system/config.json"

LIBERNET_DIR="/root/libernet"

MIHOMO_CFG="$LIBERNET_DIR/system/mihomo.yaml"

LIBERNET_CHAIN="LIBERNET"
LIBERNET_DNS_CHAIN="LIBERNET_DNS"

########################################
# helper
########################################

json() {
    jq -r "$1 // empty" "$CONFIG"
}

log() {
    "$LIBERNET_DIR/bin/log.sh" process "[routing] $1"
}

########################################
# tunnel mode
########################################

get_mode_name() {

    case "$1" in
        0) echo ssh ;;
        1) echo v2ray ;;
        2) echo ssh_ssl ;;
        3) echo trojan ;;
        4) echo shadowsocks ;;
        5) echo openvpn ;;
        6) echo qssh ;;
        7) echo ssh_ws_cdn ;;
        *) echo unknown ;;
    esac

}

MODE_ID="$(json '.tunnel.mode')"
MODE="$(get_mode_name "$MODE_ID")"

CLASH_PORT="$(json '.settings.mihomo.redir_port')"
DNS_PORT="$(json '.settings.mihomo.dns_port')"

SERVER_IP=""
PROXY_IP=""
QLOAD_PORT="7777"
WORKER_START="1080"
WORKER_COUNT="1"

########################################
# active profile
########################################

case "$MODE" in

qssh)

    PROFILE="$(json '.tunnel.profile.qssh')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/qssh/$PROFILE.json"

    if [ -f "$PROFILE_CFG" ]; then

        SERVER_IP="$(jq -r '.ip // empty' "$PROFILE_CFG")"

        PROXY_IP="$(jq -r '.proxy.host // empty' "$PROFILE_CFG")"

        QLOAD_PORT="$(jq -r '.qload_port // 7777' "$PROFILE_CFG")"

        WORKER_START="$(jq -r '.concurrency.start_port // 1080' "$PROFILE_CFG")"

        WORKER_COUNT="$(jq -r '.concurrency.workers // 1' "$PROFILE_CFG")"

    fi

;;

ssh)

    PROFILE="$(json '.tunnel.profile.ssh')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/ssh/$PROFILE.json"

    if [ -f "$PROFILE_CFG" ]; then

        SERVER_IP="$(jq -r '.server.ip // empty' "$PROFILE_CFG")"

    fi

;;

v2ray)

    PROFILE="$(json '.tunnel.profile.v2ray')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/v2ray/$PROFILE.json"

    if [ -f "$PROFILE_CFG" ]; then

        SERVER_IP="$(jq -r '.server.address // empty' "$PROFILE_CFG")"

    fi

;;

ssh_ssl)

    PROFILE="$(json '.tunnel.profile.ssh_ssl')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/ssh_ssl/$PROFILE.json"

;;

trojan)

    PROFILE="$(json '.tunnel.profile.trojan')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/trojan/$PROFILE.json"

;;

shadowsocks)

    PROFILE="$(json '.tunnel.profile.shadowsocks')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/shadowsocks/$PROFILE.json"

;;

openvpn)

    PROFILE="$(json '.tunnel.profile.openvpn')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/openvpn/$PROFILE.json"

;;

ssh_ws_cdn)

    PROFILE="$(json '.tunnel.profile.ssh_ws_cdn')"

    PROFILE_CFG="$LIBERNET_DIR/bin/config/ssh_ws_cdn/$PROFILE.json"

;;

esac
########################################
# ports
########################################

CLASH_PORT="$(json '.settings.mihomo.redir_port')"

DNS_PORT="$(json '.settings.mihomo.dns_port')"


########################################
# detect tun mode
########################################

check_tun_mode() {

    [ ! -f "$MIHOMO_CFG" ] && return 1

    if grep -A10 "^tun:" "$MIHOMO_CFG" \
        | grep -q "enable: true"
    then

        log "Detected Mihomo TUN mode"

        return 0

    fi

    return 1

}

########################################
# iptables chains
########################################

create_chains() {

    iptables -t nat -N $LIBERNET_CHAIN 2>/dev/null

    iptables -t nat -N $LIBERNET_DNS_CHAIN 2>/dev/null

}

flush_chains() {

    iptables -t nat -F $LIBERNET_CHAIN 2>/dev/null

    iptables -t nat -F $LIBERNET_DNS_CHAIN 2>/dev/null

}

delete_hooks() {

    iptables -t nat -D OUTPUT \
        -p tcp \
        -j $LIBERNET_CHAIN 2>/dev/null

    iptables -t nat -D PREROUTING \
        -i br-lan \
        -p tcp \
        -j $LIBERNET_CHAIN 2>/dev/null

    iptables -t nat -D OUTPUT \
        -p udp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN 2>/dev/null

    iptables -t nat -D OUTPUT \
        -p tcp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN 2>/dev/null

    iptables -t nat -D PREROUTING \
        -i br-lan \
        -p udp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN 2>/dev/null

    iptables -t nat -D PREROUTING \
        -i br-lan \
        -p tcp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN 2>/dev/null

}

destroy_chains() {

    iptables -t nat -X $LIBERNET_CHAIN 2>/dev/null

    iptables -t nat -X $LIBERNET_DNS_CHAIN 2>/dev/null

}
########################################
# bypass rules
########################################

apply_bypass_rules() {

    #
    # RFC1918 + reserved network
    #

    iptables -t nat -A $LIBERNET_CHAIN -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A $LIBERNET_CHAIN -d 240.0.0.0/4 -j RETURN

    #
    # bypass endpoint tunnel
    #

    if [ -n "$SERVER_IP" ]; then

        log "Bypass Server : $SERVER_IP"

        iptables -t nat -A \
            $LIBERNET_CHAIN \
            -d "$SERVER_IP" \
            -j RETURN

    fi

    #
    # bypass proxy host
    #

    if [ -n "$PROXY_IP" ] &&
       [ "$PROXY_IP" != "127.0.0.1" ]
    then

        log "Bypass Proxy : $PROXY_IP"

        iptables -t nat -A \
            $LIBERNET_CHAIN \
            -d "$PROXY_IP" \
            -j RETURN

    fi

    #
    # local dashboard
    #

    iptables -t nat -A \
        $LIBERNET_CHAIN \
        -p tcp \
        --dport 7890 \
        -j RETURN

    iptables -t nat -A \
        $LIBERNET_CHAIN \
        -p tcp \
        --dport "$CLASH_PORT" \
        -j RETURN

    iptables -t nat -A \
        $LIBERNET_CHAIN \
        -p tcp \
        --dport "$DNS_PORT" \
        -j RETURN

    iptables -t nat -A \
        $LIBERNET_CHAIN \
        -p tcp \
        --dport 9090 \
        -j RETURN

    #
    # q-load
    #

    iptables -t nat -A \
        $LIBERNET_CHAIN \
        -p tcp \
        --dport "$QLOAD_PORT" \
        -j RETURN

    #
    # bypass socks workers
    #

    if [ "$WORKER_COUNT" -gt 0 ]; then

        i=0

        while [ "$i" -lt "$WORKER_COUNT" ]
        do

            PORT=$((WORKER_START+i))

            log "Bypass Worker Port : $PORT"

            iptables -t nat -A \
                $LIBERNET_CHAIN \
                -p tcp \
                --dport "$PORT" \
                -j RETURN

            i=$((i+1))

        done

    fi

}

########################################
# redirect rules
########################################

apply_redirect_rules() {

    #
    # redirect semua TCP
    #

    iptables -t nat \
        -A $LIBERNET_CHAIN \
        -p tcp \
        -j REDIRECT \
        --to-ports "$CLASH_PORT"

    #
    # redirect DNS UDP
    #

    iptables -t nat \
        -A $LIBERNET_DNS_CHAIN \
        -p udp \
        --dport 53 \
        -j REDIRECT \
        --to-ports "$DNS_PORT"

    #
    # redirect DNS TCP
    #

    iptables -t nat \
        -A $LIBERNET_DNS_CHAIN \
        -p tcp \
        --dport 53 \
        -j REDIRECT \
        --to-ports "$DNS_PORT"

}

########################################
# hooks
########################################

get_lan_if() {

    LAN_IF="$(uci -q get network.lan.device)"

    [ -z "$LAN_IF" ] && \
    LAN_IF="$(uci -q get network.lan.ifname)"

    [ -z "$LAN_IF" ] && \
    LAN_IF="br-lan"

}

apply_hooks() {

    get_lan_if

    log "LAN Interface : $LAN_IF"

    #
    # router traffic
    #

    iptables -t nat \
        -A OUTPUT \
        -p tcp \
        -j $LIBERNET_CHAIN

    #
    # client traffic
    #

    iptables -t nat \
        -A PREROUTING \
        -i "$LAN_IF" \
        -p tcp \
        -j $LIBERNET_CHAIN

    #
    # router dns
    #

    iptables -t nat \
        -A OUTPUT \
        -p udp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN

    iptables -t nat \
        -A OUTPUT \
        -p tcp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN

    #
    # client dns
    #

    iptables -t nat \
        -A PREROUTING \
        -i "$LAN_IF" \
        -p udp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN

    iptables -t nat \
        -A PREROUTING \
        -i "$LAN_IF" \
        -p tcp \
        --dport 53 \
        -j $LIBERNET_DNS_CHAIN

}

########################################
# start
########################################

start_routing() {

    log "Initializing routing engine..."

    #
    # selalu bersihkan rule lama
    #

    stop_routing

    #
    # jika mihomo menggunakan tun
    #

    if check_tun_mode
    then

        log "Mihomo TUN mode detected"

        log "Skip NAT REDIRECT"

        return 0

    fi

    log "Applying NAT redirect rules..."

    create_chains

    flush_chains

    apply_bypass_rules

    apply_redirect_rules

    apply_hooks

    log "Routing applied successfully"

}

########################################
# stop
########################################

stop_routing() {

    log "Stopping routing..."

    delete_hooks

    flush_chains

    destroy_chains

    log "Routing stopped"

}
########################################
# status
########################################

status_routing() {

    echo
    echo "=========================================="
    echo "        LIBERNET ROUTING STATUS"
    echo "=========================================="

    echo "Mode         : $MODE"
    echo "Server IP    : ${SERVER_IP:-N/A}"
    echo "Proxy IP     : ${PROXY_IP:-N/A}"
    echo "Redir Port   : $CLASH_PORT"
    echo "DNS Port     : $DNS_PORT"
    echo "QLOAD Port   : $QLOAD_PORT"

    echo

    echo "Worker Port(s)"

    if [ "$WORKER_COUNT" -gt 0 ]; then

        i=0

        while [ "$i" -lt "$WORKER_COUNT" ]
        do

            PORT=$((WORKER_START+i))

            echo "  - $PORT"

            i=$((i+1))

        done

    fi

    echo
    echo "=========================================="
    echo "LIBERNET NAT TABLE"
    echo "=========================================="

    iptables -t nat \
        -L $LIBERNET_CHAIN \
        -n \
        --line-numbers \
        2>/dev/null || echo "Chain not found"

    echo
    echo "=========================================="
    echo "LIBERNET DNS TABLE"
    echo "=========================================="

    iptables -t nat \
        -L $LIBERNET_DNS_CHAIN \
        -n \
        --line-numbers \
        2>/dev/null || echo "Chain not found"

}

########################################
# main
########################################

case "$1" in

    start)

        start_routing

    ;;

    stop)

        stop_routing

    ;;

    restart)

        stop_routing

        sleep 1

        start_routing

    ;;

    status)

        status_routing

    ;;

    *)

        echo

        echo "Usage:"

        echo

        echo "  $0 start"

        echo "  $0 stop"

        echo "  $0 restart"

        echo "  $0 status"

        echo

        exit 1

    ;;

esac
