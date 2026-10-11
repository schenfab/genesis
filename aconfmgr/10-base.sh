# shellcheck shell=bash
# Common to every host: base system, pacman, shell tools, ssh, printing/scanning daemons.
CopyFile /etc/sudoers.d/10-wheel 440

# Packages
AddPackage base # Minimal package set to define a basic Arch Linux installation
AddPackage bash # The GNU Bourne Again shell
AddPackage bash-completion # Programmable completion for the bash shell
AddPackage binutils # A set of programs to assemble and manipulate binary and object files
AddPackage bzip2 # A high-quality data compression program
AddPackage convmv # Tool for converting encodings on filesystems
AddPackage coreutils # The basic file, shell and text manipulation utilities of the GNU operating system
AddPackage cryptsetup # Userspace setup tool for transparent encryption of block devices using dm-crypt
AddPackage detox # An utility designed to clean up filenames by replacing characters with standard equivalents
AddPackage device-mapper # Device mapper userspace library and tools
AddPackage diffutils # Utility programs used for creating patch files
AddPackage dmidecode # Desktop Management Interface table related utilities
AddPackage dnsmasq # Lightweight, easy to configure DNS forwarder and DHCP server
AddPackage dos2unix # Text file format converter
AddPackage e2fsprogs # Ext2/3/4 filesystem utilities
AddPackage etckeeper # Collection of tools to let /etc be stored in a git, hg or bzr repository
AddPackage ex-vi-compat # The ex and vi commands based on vim's compatibility modes
AddPackage expect # A tool for automating interactive applications
AddPackage file # File type identification utility
AddPackage filesystem # Base Arch Linux files
AddPackage findutils # GNU utilities to locate files
AddPackage gawk # GNU version of awk
AddPackage gcc-libs # Runtime libraries shipped by GCC
AddPackage gettext # GNU internationalization library
AddPackage glibc # GNU C Library
AddPackage grep # A string search utility
AddPackage gzip # GNU compression utility
AddPackage htop # Interactive process viewer
AddPackage img2pdf # Losslessly convert raster images to PDF
AddPackage inetutils # A collection of common network programs
AddPackage iotop # View I/O usage of processes
AddPackage iperf3 # TCP, UDP, and SCTP network bandwidth measurement tool
AddPackage iproute2 # IP Routing Utilities
AddPackage iputils # Network monitoring tools, including ping
AddPackage jfsutils # JFS filesystem utilities
AddPackage less # A terminal based program for viewing text files
AddPackage licenses # A set of common license files
AddPackage linux # The Linux kernel and modules
AddPackage linux-firmware # Firmware files for Linux - Default set
AddPackage logrotate # Rotates system logs automatically
AddPackage lshw # A small tool to provide detailed information on the hardware configuration of the machine.
AddPackage lsof # Lists open files for running Unix processes
AddPackage lvm2 # Logical Volume Manager 2 utilities
AddPackage man-db # A utility for reading man pages
AddPackage man-pages # Linux man pages
AddPackage mdadm # A tool for managing/monitoring Linux md device arrays, also known as Software RAID
AddPackage minicom # A serial communication program
AddPackage nano # Pico editor clone with enhancements
AddPackage networkmanager # Network connection manager and user applications
AddPackage ntfs-3g # NTFS FUSE driver
AddPackage openvpn # An easy-to-use, robust and highly configurable VPN (Virtual Private Network)
AddPackage pacman # A library-based package manager with dependency support
AddPackage pacman-contrib # Contributed scripts and tools for pacman systems
AddPackage pciutils # PCI bus configuration space access library and tools
AddPackage pdftk # Command-line tool for working with PDFs
AddPackage perl # A highly capable, feature-rich programming language
AddPackage perl-image-exiftool # Read and write EXIF information
AddPackage procps-ng # Utilities for monitoring your system and its processes
AddPackage psmisc # Miscellaneous procfs tools
AddPackage rclone # rsync for cloud storage
AddPackage sed # GNU stream editor
AddPackage shadow # Password and account management tool suite with support for shadow files and PAM
AddPackage smartmontools # Control and monitor S.M.A.R.T. enabled ATA and SCSI Hard Drives
AddPackage socat # Multipurpose relay
AddPackage strace # A diagnostic, debugging and instructional userspace tracer
AddPackage sudo # Give certain users the ability to run some commands as root
AddPackage sysfsutils # System Utilities Based on Sysfs
AddPackage systemd-sysvcompat # sysvinit compat for systemd
AddPackage tar # Utility used to store, backup, and transport files
AddPackage texinfo # GNU documentation system for on-line information and printed output
AddPackage tmux # Terminal multiplexer
AddPackage tree # A directory listing program displaying a depth indented list of files
AddPackage usbutils # A collection of USB tools to query connected USB devices
AddPackage util-linux # Miscellaneous system utilities for Linux
AddPackage wget # Network utility to retrieve files from the web
AddPackage which # A utility to show the full path of commands
AddPackage xfsprogs # XFS filesystem utilities
AddPackage --foreign yay-bin # Yet another yogurt. Pacman wrapper and AUR helper written in go. Pre-compiled.

# Files, links and services
CreateDir /etc/audisp
CreateDir /etc/audit/plugins.d 750
CreateDir /etc/audit/rules.d
CreateDir /etc/cni/net.d 700
CopyFile /etc/locale.conf
CopyFile /etc/locale.gen
CreateLink /etc/localtime /usr/share/zoneinfo/Europe/Zurich
CopyFile /etc/openvpn/scripts/update-resolv-conf 755
CopyFile /etc/openvpn/scripts/update-systemd-resolved 755
CreateDir /etc/openvpn/server 750 openvpn network
CreateLink /etc/os-release ../usr/lib/os-release
CopyFile /etc/pacman.d/mirrorlist
CopyFile /etc/papersize
CopyFile /etc/shells
CopyFile /etc/ssh/sshd_config
CopyFile /etc/sudoers 440
CreateLink /etc/systemd/system/autovt@.service /usr/lib/systemd/system/getty@.service
CreateLink /etc/systemd/system/getty.target.wants/getty@tty1.service /usr/lib/systemd/system/getty@.service
CreateLink /etc/systemd/system/multi-user.target.wants/etckeeper.timer /usr/lib/systemd/system/etckeeper.timer
CreateLink /etc/systemd/system/multi-user.target.wants/remote-fs.target /usr/lib/systemd/system/remote-fs.target
CreateLink /etc/systemd/system/multi-user.target.wants/sshd.service /usr/lib/systemd/system/sshd.service
CreateLink /etc/systemd/system/timers.target.wants/fstrim.timer /usr/lib/systemd/system/fstrim.timer
CreateLink /etc/systemd/system/timers.target.wants/paccache.timer /usr/lib/systemd/system/paccache.timer
SetFileProperty /etc/cni mode 700
SetFileProperty /usr/lib/utempter/utempter group utmp
SetFileProperty /usr/lib/utempter/utempter mode 2755
CopyFile /etc/pacman.conf
CopyFile /etc/vconsole.conf
# NetworkManager is the network stack on new hosts (moog opts out in hosts/moog.sh).
CreateLink /etc/systemd/system/multi-user.target.wants/NetworkManager.service /usr/lib/systemd/system/NetworkManager.service
CreateLink /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service /usr/lib/systemd/system/NetworkManager-dispatcher.service
CreateLink /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service /usr/lib/systemd/system/NetworkManager-wait-online.service

# Tools genesis itself needs (aconfmgr installs pacutils only as a dependency, which apply would prune).
AddPackage git
AddPackage pacutils
