#!/bin/sh

CONFIG="/root/libernet/system/config.json"
LOCK="/tmp/config-switch.lock"

[ -f "$LOCK" ] && exit 0

touch "$LOCK"

trap 'rm -f "$LOCK"' EXIT
log() {
    /root/libernet/bin/log.sh \
    -w "<span style=\"color:orange\">[AUTO-SWITCH] $1</span>"
}

# mode -> profile key
MODE="$(jq -r '.tunnel.mode' "$CONFIG")"

case "$MODE" in
    0)
        KEY="ssh"
        DIR="/root/libernet/bin/config/ssh"
    ;;
    1)
        KEY="v2ray"
        DIR="/root/libernet/bin/config/v2ray"
    ;;
    2)
        KEY="qssh"
        DIR="/root/libernet/bin/config/qssh"
    ;;
    *)
        echo "Unknown mode"
        exit 1
    ;;
esac

CURRENT="$(jq -r ".tunnel.profile.${KEY}" "$CONFIG")"

FILES="$(ls "$DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//')"

[ -z "$FILES" ] && exit 1

NEXT=""
FOUND=0
FIRST=""

for CFG in $FILES
do

    [ -z "$FIRST" ] && FIRST="$CFG"

    if [ "$FOUND" = "1" ]; then

        NEXT="$CFG"
        break

    fi

    [ "$CFG" = "$CURRENT" ] && FOUND=1

done

# kalau config terakhir -> balik ke awal
[ -z "$NEXT" ] && NEXT="$FIRST"

# update config.json
TMP="/tmp/libernet_config.$$"

jq ".tunnel.profile.${KEY} = \"${NEXT}\"" \
"$CONFIG" > "$TMP"

if jq empty "$TMP" 2>/dev/null; then

    mv "$TMP" "$CONFIG"

    log "${CURRENT} → ${NEXT}"

    echo "$NEXT"

else

    rm -f "$TMP"

    log "Config update failed"

    exit 1

fi