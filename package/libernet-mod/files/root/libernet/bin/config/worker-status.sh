#!/bin/sh

#=========================================================
# Worker Status v2 (inode based)
#=========================================================

get_worker_pid() {
    local PORT="$1"

    ps | awk -v port="$PORT" '
        $0 ~ "ssh -4CND " port &&
        $0 !~ /sshpass/ &&
        $0 !~ /awk/ {
            print $1
            exit
        }
    '
}

tcp_state() {
    case "$1" in
        01) echo "CONNECTED" ;;
        02) echo "CONNECTING" ;;
        03) echo "SYN_RECV" ;;
        04) echo "FIN_WAIT1" ;;
        05) echo "FIN_WAIT2" ;;
        06) echo "TIME_WAIT" ;;
        07) echo "CLOSED" ;;
        08) echo "CLOSE_WAIT" ;;
        09) echo "LAST_ACK" ;;
        0A) echo "LISTEN" ;;
        *)  echo "$1" ;;
    esac
}

hex_to_ip() {
    local h="$1"

    printf "%d.%d.%d.%d" \
        0x${h:6:2} \
        0x${h:4:2} \
        0x${h:2:2} \
        0x${h:0:2}
}

hex_to_port() {
    printf "%d" "0x$1"
}

worker_status() {

    local PORT="$1"
    local PID

    PID=$(get_worker_pid "$PORT")

    echo "======================================"
    echo "Worker Port : $PORT"

    if [ -z "$PID" ]; then
        echo "PID    : -"
        echo "State  : STOPPED"
        echo
        return
    fi

    echo "PID    : $PID"

    #
    # Ambil semua inode socket milik proses ssh
    #
    for INODE in $(ls -l /proc/$PID/fd 2>/dev/null | \
        sed -n 's/.*socket:\[\([0-9]*\)\].*/\1/p')
    do

        awk -v inode="$INODE" '
        NR==1 {next}

        $10==inode {

            split($2,l,":")
            split($3,r,":")

            #
            # skip LISTEN
            #
            if ($4=="0A")
                next

            #
            # skip remote kosong
            #
            if (r[1]=="00000000")
                next

            #
            # skip localhost
            #
            if (l[1]=="0100007F")
                next

            print r[1], r[2], $4
            exit
        }

        ' /proc/net/tcp

    done | while read RIP RPORT STATE
    do

        echo "Remote : $(hex_to_ip "$RIP"):$(hex_to_port "$RPORT")"
        echo "State  : $(tcp_state "$STATE")"
        echo
        return

    done

    echo "Remote : -"
    echo "State  : UNKNOWN"
    echo
}

#
# MAIN
#

if [ $# -gt 0 ]; then

    worker_status "$1"

else

    for PORT in $(ps | sed -n 's/.*-4CND \([0-9]*\).*/\1/p'); do
        worker_status "$PORT"
    done

fi