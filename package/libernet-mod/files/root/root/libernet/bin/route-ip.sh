#!/bin/sh

TABLE_ID=2022
MARK=0x162
META_DEV="Meta"
LAN_IF="br-lan"

log() {
    "${LIBERNET_DIR}/bin/log.sh" -w "$1"
}

create_policy_route() {

    ip rule del fwmark ${MARK} table ${TABLE_ID} 2>/dev/null

    ip rule add fwmark ${MARK} table ${TABLE_ID} priority 1888

}

remove_policy_route() {

    ip rule del fwmark ${MARK} table ${TABLE_ID} 2>/dev/null

}

create_mangle() {

    iptables -t mangle -N LIBERNET_MARK 2>/dev/null
    iptables -t mangle -F LIBERNET_MARK

    # bypass lokal
    iptables -t mangle -A LIBERNET_MARK -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 240.0.0.0/4 -j RETURN
    iptables -t mangle -A LIBERNET_MARK -d 198.18.0.0/16 -j RETURN

    # mark semua trafik lain
    iptables -t mangle -A LIBERNET_MARK -j MARK --set-mark ${MARK}

    iptables -t mangle -D PREROUTING -i ${LAN_IF} -j LIBERNET_MARK 2>/dev/null
    iptables -t mangle -A PREROUTING -i ${LAN_IF} -j LIBERNET_MARK
}

remove_mangle() {

    iptables -t mangle -D PREROUTING -i ${LAN_IF} -j LIBERNET_MARK 2>/dev/null

    iptables -t mangle -F LIBERNET_MARK 2>/dev/null
    iptables -t mangle -X LIBERNET_MARK 2>/dev/null
}

create_dns() {

    iptables -t nat -D PREROUTING -i ${LAN_IF} -p udp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null
    iptables -t nat -D PREROUTING -i ${LAN_IF} -p tcp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null

    iptables -t nat -A PREROUTING -i ${LAN_IF} -p udp --dport 53 -j REDIRECT --to-ports 1053
    iptables -t nat -A PREROUTING -i ${LAN_IF} -p tcp --dport 53 -j REDIRECT --to-ports 1053
}

remove_dns() {

    iptables -t nat -D PREROUTING -i ${LAN_IF} -p udp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null
    iptables -t nat -D PREROUTING -i ${LAN_IF} -p tcp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null
}
wait_meta() {

    local i=0

    while ! ip link show ${META_DEV} >/dev/null 2>&1; do
        sleep 1
        i=$((i+1))

        [ "$i" -ge 15 ] && return 1
    done

    return 0
}

cleanup_routing() {

    remove_dns
    remove_mangle
    remove_policy_route
}
start_routing() {

    cleanup_routing

    wait_meta || {
        log "[ROUTING] Meta interface not ready"
        return 1
    }

    create_policy_route
    create_mangle
    create_dns

    log "[ROUTING] TUN Mode Active (Meta)"
}
stop_routing() {

    cleanup_routing

    log "[ROUTING] TUN Mode Stopped"
}

status_routing() {

    echo "=== RULE ==="
    ip rule

    echo
    echo "=== TABLE ${TABLE_ID} ==="
    ip route show table ${TABLE_ID}

    echo
    echo "=== MANGLE ==="
    iptables -t mangle -L -n -v
}

case "$1" in
    start) start_routing ;;
    stop) stop_routing ;;
    restart) stop_routing; sleep 1; start_routing ;;
    status) status_routing ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac