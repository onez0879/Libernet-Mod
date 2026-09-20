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
endef

define Package/libernet-mod/description
  Libernet Mod web interface, scripts and ARM64 helper binaries.
  Runtime dependencies are installed separately on the target device.
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
	cp -a "$(PKG_BUILD_DIR)/." "$(1)/"
endef

$(eval $(call BuildPackage,libernet-mod))
