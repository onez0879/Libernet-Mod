# Libernet-Mod IPK build

This repository packages a Libernet-Mod backup as an OpenWrt `.ipk`. The backup
contains ARM64 binaries, so the included workflow builds with the official
OpenWrt 24.10 `armsr/armv8` SDK and emits an `aarch64_generic` package.

## Add the backup

Copy the three folders from the backup into this exact location, preserving all
subfolders and file names:

```
package/libernet-mod/files/root/
package/libernet-mod/files/www/
package/libernet-mod/files/usr/
```

For example, `root/libernet/bin/service.sh` in the backup becomes
`package/libernet-mod/files/root/libernet/bin/service.sh` in this repository.

Do not upload router-specific credentials or state. `.gitignore` lists the
known live configuration, cache, log, and connection-profile files that should
stay private. Review all JSON, YAML, PEM, and PHP configuration files before
publishing a public repository.

## Build

Commit and push the backup files to `main`, then open the **Actions** tab and
select **Build Libernet-Mod IPK**. When it finishes, download the
`libernet-mod-ipk-openwrt-24.10-arm64` artifact. The `.ipk` is inside it.

The included ELF binaries are ARM64. This package must not be installed on
x86, MIPS, or 32-bit ARM devices. It is intended for OpenWrt 24.10 builds
compatible with the `aarch64_generic` package architecture.
