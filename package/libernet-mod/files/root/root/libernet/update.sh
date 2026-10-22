#!/bin/bash

# Libernet Updater (Libernet-Mod / OpenWrt package edition)
#
# In-place self-update is DISABLED in this fork.
#
# The upstream installer cloned github.com/lutfailham96/libernet over the
# running installation with `git reset --hard`, which overwrote the packaged
# files and pulled in a different (unmodded) tree. This package is distributed
# as an OpenWrt .ipk instead, so updates go through opkg.

LIBERNET_DIR="${LIBERNET_DIR:-/root/libernet}"

log_update() {
  if [ -x "${LIBERNET_DIR}/bin/log.sh" ]; then
    "${LIBERNET_DIR}/bin/log.sh" "$@"
  fi
}

update_libernet_web() {
  log_update -u 1
  echo "Self-update is disabled in Libernet-Mod. Update with:"
  echo "  opkg update && opkg install --force-reinstall libernet-mod"
  log_update -u 2
}

case "$1" in
  -web)
    update_libernet_web
    ;;
  *)
    echo "Self-update is disabled in Libernet-Mod."
    echo "Update with: opkg update && opkg install --force-reinstall libernet-mod"
    ;;
esac
