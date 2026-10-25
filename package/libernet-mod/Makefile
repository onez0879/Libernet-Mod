include $(TOPDIR)/rules.mk

PKG_NAME:=libernet-mod
PKG_VERSION:=2026.10.22.6
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKGARCH:=aarch64_generic

PKG_LICENSE:=Proprietary
PKG_MAINTAINER:=onez0879

include $(INCLUDE_DIR)/package.mk

define Package/libernet-mod
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Libernet Mod web interface and tunnel scripts
  URL:=https://github.com/onez0879/Libernet-Mod
  DEPENDS:=+bash +curl +librt +libpthread +coreutils +coreutils-stdbuf +screen \
	+jq +ip-full +iptables-nft +openssh-client +dnsmasq-full +stubby \
	+php8 +php8-cgi +php8-mod-session +python3 +httping +https-dns-proxy \
	+stunnel +v2ray-core +openvpn-openssl +kmod-tun +shadowsocks-libev-ss-local +php8-cli
endef

define Package/libernet-mod/description
  Libernet Mod web interface, scripts and ARM64 helper binaries.
  Runtime dependencies are installed separately on the target device.
endef

# postinst inline: gunakan $$ untuk escape variable shell dari make expansion.
# Tanpa escape, ${IPKG_NO_SCRIPT} / ${IPKG_INSTROOT} diurai make → kosong,
# dan guard skip tidak jalan saat image build atau instalasi opkg.
define Package/libernet-mod/postinst
#!/bin/sh
#
# postinst libernet-mod
# Setup runtime setelah opkg install / upgrade.
#

# Lewati saat image build / opkg tidak mengeksekusi script.
[ -n "$${IPKG_NO_SCRIPT}" ] && exit 0
[ -n "$${IPKG_INSTROOT}" ] && exit 0

LIBDIR="/root/libernet"
CFG="$${LIBDIR}/system/config.json"
CFGDEF="$${LIBDIR}/system/config.default.json"

# 1. Script bin/*.sh harus executable — service.sh dan turunan gagal tanpa ini.
if [ -d "$${LIBDIR}/bin" ]; then
    chmod +x "$${LIBDIR}/bin/"*.sh 2>/dev/null
fi

# 2. Seed config.json dari config.default.json kalau belum ada.
#    api.php baca/tulis ke config.json; tanpa file ini semua save config gagal.
if [ ! -f "$${CFG}" ] && [ -f "$${CFGDEF}" ]; then
    cp "$${CFGDEF}" "$${CFG}"
    chmod 600 "$${CFG}"
fi

# 3. Direktori runtime (log dan lainnya).
mkdir -p "$${LIBDIR}/log" 2>/dev/null

# 4. Daftarkan PHP-CGI ke uhttpd supaya /libernet/*.php dieksekusi, bukan diunduh.
#    Idempotent: tidak melakukan apa-apa kalau alias sudah ada.
if command -v uci >/dev/null 2>&1; then
    if ! uci -q show uhttpd.main 2>/dev/null | grep -q 'interpreter.*\\.php='; then
        uci -q add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
        uci commit uhttpd
        /etc/init.d/uhttpd reload >/dev/null 2>&1 \
            || /etc/init.d/uhttpd restart >/dev/null 2>&1
    fi
fi

exit 0
endef


define Build/Prepare
	rm -rf "$(PKG_BUILD_DIR)"
	mkdir -p "$(PKG_BUILD_DIR)"
	cp -a ./files/. "$(PKG_BUILD_DIR)/"
endef

define Build/Compile
endef

define Package/libernet-mod/install
	$(INSTALL_DIR) $(1)
	cp -a "$(PKG_BUILD_DIR)/root/." "$(1)/" 2>/dev/null || true
	cp -a "$(PKG_BUILD_DIR)/usr/." "$(1)/usr/" 2>/dev/null || true
	cp -a "$(PKG_BUILD_DIR)/www/." "$(1)/www/" 2>/dev/null || true
endef

$(eval $(call BuildPackage,libernet-mod))
