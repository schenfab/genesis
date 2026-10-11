# shellcheck shell=bash
# Paths aconfmgr must neither capture (save) nor touch (apply).
# Keep in sync with hooks/pre-commit (tests/test_aconfmgr_config.py checks this).

# Private material: never in this public repo (see docs/post-install.md).
IgnorePath '/etc/ssh/ssh_host_*'
IgnorePath '/etc/docker/key.json' '/etc/docker/certs.d/*'
IgnorePath '/etc/openvpn/client/*' '/etc/openvpn/server/*'
IgnorePath '/etc/NetworkManager/system-connections/*'
IgnorePath '/etc/ca-certificates/trust-source/*'
IgnorePath '/etc/credstore*' '/etc/cryptsetup-keys.d'
IgnorePath '/etc/cups/ppd/*' '/etc/cups/printers.conf*' '/etc/cups/classes.conf*' '/etc/cups/subscriptions.conf*' '/etc/printcap'
IgnorePath '/etc/systemd/system/*OneDrive*.mount'

# Accounts: created by archinstall, groups by the genesis users step.
IgnorePath '/etc/passwd*' '/etc/shadow*' '/etc/group*' '/etc/gshadow*' '/etc/subuid*' '/etc/subgid*' '/etc/.pwd.lock'

# Machine identity and install-time state.
IgnorePath '/etc/machine-id' '/etc/hostname' '/etc/adjtime' '/etc/fstab' '/etc/.updated'
IgnorePath '/etc/ld.so.cache' '/etc/pacman.d/gnupg/*' '/etc/ca-certificates/extracted/*' '/etc/ssl/certs/*'
IgnorePath '/etc/.git' '/etc/.etckeeper' '/etc/.gitignore'
IgnorePath '/boot/*' '/swap' '/swapfile' '/.snapshots' '/lost+found'

# Runtime state and caches outside /etc.
IgnorePath '/var/*' '/usr/lib/modules/*' '/usr/share/mime/*' '/usr/lib/locale/locale-archive'

# Editor backups.
IgnorePath '*~'
