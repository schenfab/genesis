# Post-install checklist (private items, not in this repo)

These are deliberately kept out of the public repo. aconfmgr ignores their paths
(`aconfmgr/00-ignore.sh`), so `genesis apply` never deletes them.

- [ ] OpenVPN client config → `/etc/openvpn/client/client.conf` (mode 600), then `systemctl enable --now openvpn-client@client` if wanted
- [ ] Work CA certificates → `/etc/ca-certificates/trust-source/anchors/` (or `trust anchor --store <cert>`), then `update-ca-trust`
- [ ] Docker registry CA → `/etc/docker/certs.d/<registry>/ca.crt`
- [ ] OneDrive mount unit → `/etc/systemd/system/home-<user>-OneDrive.mount`, then `systemctl enable` it
- [ ] Printer: add via CUPS web UI (http://localhost:631) or GNOME Settings; HP needs `hp-setup` (hplip)
- [ ] Wi-Fi / VPN connections in NetworkManager (re-enter in GNOME Settings)
- [ ] Dropbox: `systemctl enable --now dropbox@<user>` after first login (if installed on this host)
