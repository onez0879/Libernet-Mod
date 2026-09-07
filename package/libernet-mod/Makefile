include $(TOPDIR)/rules.mk

PKG_NAME:=libernet-mod
PKG_VERSION:=2026.09.08
PKG_RELEASE:=1
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
  DEPENDS:=+bash +curl +ip-full +jq +luci-base +luci-compat +php8 +php8-cgi +php8-mod-json +php8-mod-session
endef

define Package/libernet-mod/description
  Libernet Mod files packaged from a local OpenWrt backup. This package carries
  ARM64 helper binaries and must be built for an ARM64 OpenWrt 24.10 target.
endef

define Build/Prepare
	$(RM) -r $(PKG_BUILD_DIR)
	$(MKDIR) $(PKG_BUILD_DIR)
	$(CP) ./files/. $(PKG_BUILD_DIR)/
endef

define Build/Compile
endef

define Package/libernet-mod/install
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_BUILD_DIR)/. $(1)/
endef

$(eval $(call BuildPackage,libernet-mod))
