# genesis — Arch Linux machine bootstrap

Date: 2026-10-11
Status: design approved, pending implementation plan

## Goal

Bootstrap any of my Arch Linux machines from the Arch live ISO to my taste:
partitions/filesystems, base system, users, all installed packages (repo + AUR),
and all changes to system configuration (`/etc`, enabled services). Keep the
repo and every machine in sync over time.

## Constraints and decisions

- **Arch Linux only.**
- **Arch defaults at install time win.** Bootloader, network backend, swap/zram,
  firmware mode (UEFI preferred) are not pinned; archinstall's current defaults
  are used. Only genuine preferences are pinned.
- **Disk policy (pinned):** btrfs with subvolumes (archinstall default btrfs
  layout), so filesystems can grow/shrink and span disks later
  (`btrfs device add/remove`). No LVM. No encryption.
- **Multiple hosts** share one repo: a common layer plus a per-host layer,
  selected by hostname.
- **Users:** `fschenkel` (admin/wheel), `guest`, `andrea` on every host.
- **Public repo: no secrets at all,** not even password hashes. Passwords
  (root + 3 users) are prompted during install.
- **Private items** (VPN config, work CA certs, docker registry cert, OneDrive
  mount, printer PPD) are **not stored**; they go on a manual post-install
  checklist. The design leaves room for a later optional private overlay repo.
- **Two-way sync:** machines can be diffed against the repo and changes
  captured back, or the repo applied to a machine.
- **Out of scope (for now):** home directory / dotfiles, private overlay repo,
  secure boot, encryption, snapshot tooling.

## Tools

- **archinstall** (on the ISO) — stage 1, base system.
- **aconfmgr** (git submodule, run from checkout) — stage 2 and ongoing sync of
  packages (incl. AUR, built via makepkg), `/etc` files, and systemd unit links.

## Repository layout

```
genesis/
├── genesis                  # entry point: genesis install|apply|save|check
├── README.md                # full workflow incl. step-by-step live ISO instructions
├── install/
│   ├── bootstrap.sh         # live ISO: pick host, build config, prompt passwords, run archinstall
│   ├── archconf.py          # merges archinstall JSON, builds creds (yescrypt hashes, RAM only)
│   └── users.sh             # stage-2 users step (supplementary groups)
├── hosts/
│   ├── common/
│   │   ├── archinstall.json # shared stage-1 choices
│   │   └── users            # data: `<user> <groups...>`; `wheel` = admin/sudo
│   └── <host>/
│       └── archinstall.json # hostname + host-specific stage-1 overrides
├── aconfmgr/                # aconfmgr config dir
│   ├── 00-ignore.sh         # private / machine-specific paths: never captured, never deleted
│   ├── 10-base.sh
│   ├── 20-desktop.sh
│   ├── 30-dev.sh
│   ├── 50-host.sh           # sources hosts/$HOSTNAME.sh
│   ├── hosts/<host>.sh
│   ├── 99-unsorted.sh       # output of `genesis save`, to be sorted
│   └── files/               # stored /etc files (host-specific under files/hosts/<host>/)
├── vendor/aconfmgr/         # git submodule, pinned commit
├── hooks/pre-commit         # secret guard (also run in CI with --all)
├── tests/                   # pytest suite (+ tests/vm/run.sh for the VM test)
├── .github/workflows/ci.yml # pytest, shellcheck, secret guard on every push
└── docs/
    └── post-install.md      # manual checklist for private items
```

## Stage 1 — live ISO to bootable base system (`genesis install`)

Run from the live ISO after `pacman -Sy git` and cloning the repo.

1. Select host from `hosts/*` or enter a new name (new host = common defaults only).
2. Merge `hosts/common/archinstall.json` with `hosts/<host>/archinstall.json`
   (Python, available on the ISO) into a temp config.
   - Pinned: locale `en_US.UTF-8` (+ `de_CH.UTF-8` generated), console keymap
     `de_CH-latin1`, timezone `Europe/Zurich`, hostname, kernel `linux`, GNOME
     profile (gdm), PipeWire, NetworkManager (an unset network config would
     leave the system offline), extra package `git`.
   - Not pinned: target disk, bootloader, swap/zram.
   - Disk policy: archinstall cannot pin "default layout + btrfs" without also
     pinning device and sizes, so the user selects default layout → btrfs →
     default subvolumes → compression in the menu; README and bootstrap
     on-screen instructions spell this out.
3. Prompt for passwords: root, `fschenkel`, `guest`, `andrea`. Write a creds
   file (yescrypt hashes via libcrypt, mode 0600) to RAM-backed `/tmp` on the
   ISO, pass via `--creds`, delete afterwards. Users come from
   `hosts/common/users`; users listed with `wheel` get `sudo: true`.
4. Launch archinstall's interactive menu prefilled with the merged config; the
   user picks the disk, reviews defaults, installs.
5. `custom_commands` clone the repo (with submodule) to
   `/home/fschenkel/repos/genesis`, owned by `fschenkel`.

Supplementary groups are deferred to stage 2 (groups don't exist yet).

## Stage 2 — apply (`genesis apply`)

Run by the user in their own terminal (aconfmgr uses sudo interactively).

1. `aconfmgr apply` on `aconfmgr/` (common + current host). Shows planned
   changes — package installs **and removals**, file changes, unit links — and
   asks before acting.
2. Users step: apply supplementary groups from `hosts/common/users`
   (`fschenkel`: wheel, docker, scanner, uucp, uinputg) via `usermod -aG`,
   creating missing groups as system groups. Never touches passwords.

Kernel/driver parameters are expressed as modprobe options in
`/etc/modprobe.d/` (e.g. `options amdgpu runpm=0` on moog), so they are plain
files managed by aconfmgr and independent of the bootloader. No separate host step.

`genesis check` runs `aconfmgr check` (config lint).

## Sync — capture (`genesis save`)

1. `aconfmgr save` writes all drift to `aconfmgr/99-unsorted.sh` and `aconfmgr/files/`.
2. The user (optionally with Claude's help) moves entries into the themed common
   files or `hosts/<host>.sh`, reviews with `git diff`, commits.

## Safety

- **Ignore, don't delete:** `00-ignore.sh` lists private/machine-specific paths
  so aconfmgr neither captures nor removes them: `/etc/ssh/ssh_host_*`,
  `/etc/docker/key.json`, `/etc/openvpn/client/*`,
  `/etc/NetworkManager/system-connections/*`, `/etc/{passwd,shadow,group,gshadow}*`,
  `/etc/machine-id`, work CA certs under `/etc/ca-certificates/trust-source/`,
  `/etc/docker/certs.d/*`, CUPS printer state/PPDs, generated caches.
- **Pre-commit secret guard:** rejects private-key/credential-looking content
  and paths on the private list.
- `apply` always previews and confirms; package removal included.

## Host model

- A host = `hosts/<name>/archinstall.json` + `aconfmgr/hosts/<name>.sh`.
- Common files hold what every machine gets; host files add hardware/machine
  specifics and may `RemovePackage` common ones.
- New machine: choose a new name at install; first `genesis save` on it seeds
  its host file.

## Initial capture from moog

- Run `genesis save` on moog; sort into common vs `moog`.
- Legacy choices (GRUB, dhcpcd, ntpdate, `/swap` swapfile, ext4) go to
  `moog.sh` only — not inherited by new machines.
- Clean up cruft (`*~`, `*.O`, `resolv.conf.bak`).
- Done when `genesis apply` on moog reports no changes.

## Testing

- QEMU VM with OVMF (UEFI): boot Arch ISO → `genesis install` (test host) →
  reboot → `genesis apply` succeeds → second `genesis apply` reports no changes.
- README documents how to rerun the VM test. A faster variant skipping AUR
  builds may be added if full runs prove too slow.
