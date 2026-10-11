# shellcheck shell=bash
# moog: Dell OptiPlex 790 (legacy BIOS, GRUB, ext4, dhcpcd), AMD RX 460, Logitech G15.

# Packages
AddPackage dhcpcd # DHCP/ IPv4LL/ IPv6RA/ DHCPv6 client
AddPackage grub # GNU GRand Unified Bootloader (2)
AddPackage intel-ucode # Microcode update files for Intel CPUs
AddPackage netctl # Profile based systemd network management
AddPackage ntp # Network Time Protocol reference implementation
AddPackage --foreign g15daemon # A daemon that makes it possible to use the G-Buttons and draw on the G15 LCD
AddPackage --foreign g15daemon-systemd # g15daemon init script for systemd

# Files, links and services
CopyFile /etc/dconf/db/local.d/00-hidpi
CopyFile /etc/dconf/db/locks/hidpi
CopyFile /etc/default/grub
CopyFile /etc/g15daemon.conf
CopyFile /etc/hosts
CopyFile /etc/systemd/system/g15daemon.service.d/override.conf
CreateLink /etc/systemd/system/multi-user.target.wants/dhcpcd.service /usr/lib/systemd/system/dhcpcd.service
CreateLink /etc/systemd/system/multi-user.target.wants/g15daemon.service /usr/lib/systemd/system/g15daemon.service
CreateLink /etc/systemd/system/multi-user.target.wants/ntpdate.service /usr/lib/systemd/system/ntpdate.service
CopyFile /etc/systemd/system/ntpdate.service.d/hwclock.conf
CreateLink /usr/lib/libjpeg.so.9 /usr/local/lib/libjpeg-x86_64.so.9.2.0
CreateLink /usr/lib/libvsscript.so libvapoursynth-script.so.0
CopyFile /usr/share/glib-2.0/schemas/93_hidpi.gschema.override

# moog variants of common files.
CopyFileTo /hosts/moog/etc/pacman.conf /etc/pacman.conf   # IgnorePkg pins the G15 packages
CopyFileTo /hosts/moog/etc/vconsole.conf /etc/vconsole.conf   # large console font
CopyFile /etc/modprobe.d/amdgpu.conf

# moog uses dhcpcd instead of NetworkManager.
RemoveFile /etc/systemd/system/multi-user.target.wants/NetworkManager.service
RemoveFile /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service
RemoveFile /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
RemoveFile /etc/systemd/system/network-online.target.wants
