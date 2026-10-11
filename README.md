# genesis

Bootstrap my Arch Linux machines from the live ISO, and keep their packages,
`/etc` and services in sync with this repo.

- **Stage 1** (`genesis install`, live ISO): [archinstall](https://github.com/archlinux/archinstall)
  with my pinned preferences (`hosts/`), Arch's current defaults for everything else.
- **Stage 2 + sync** (`genesis apply` / `genesis save`): [aconfmgr](https://github.com/CyberShadow/aconfmgr)
  manages packages (incl. AUR), `/etc` files and enabled services (`aconfmgr/`).

This repo is public: it contains **no secrets**. Passwords are prompted during
install; private config is restored by hand (`docs/post-install.md`).

## Install a machine from the Arch live ISO

1. Boot the [Arch ISO](https://archlinux.org/download/) (UEFI mode if the machine supports it).
2. Keyboard and network:
   ```
   loadkeys de_CH-latin1
   iwctl            # Wi-Fi only: station wlan0 connect <SSID>
   ping -c1 archlinux.org
   ```
3. Get genesis and start:
   ```
   pacman -Sy git
   git clone https://github.com/schenfab/genesis
   cd genesis
   ./genesis install          # or: ./genesis install <host>
   ```
4. Pick the host (existing name, or a new name for a new machine).
5. Enter passwords for root, fschenkel, guest, andrea (each twice).
6. In the archinstall menu:
   - **Disk configuration** → default (best-effort) layout → select disk →
     **btrfs** → default subvolumes **yes** → compression **yes**
   - Leave bootloader and swap at the defaults.
   - Review, then **Install**. Reboot when done.
7. Log in as `fschenkel` and run:
   ```
   ~/repos/genesis/genesis apply
   ```
   It shows every change (packages to install/remove, files, services) and asks
   before acting. AUR packages are built locally and take a while.
8. Work through `docs/post-install.md`.

## Day to day

| Command | What it does |
|---|---|
| `genesis apply` | Make this machine match the repo. Asks before each change, **including removing packages that are not in the repo.** |
| `genesis save` | Record this machine's drift (new packages, changed `/etc` files, enabled services) into `aconfmgr/99-unsorted.sh` + `aconfmgr/files/`. |
| `genesis check` | Lint the aconfmgr config. |

After `genesis save`: move each line of `aconfmgr/99-unsorted.sh` into the right
file, delete `99-unsorted.sh`, review `git diff`, commit.

- `aconfmgr/10-base.sh`, `20-desktop.sh`, `30-dev.sh`: every machine
- `aconfmgr/hosts/<host>.sh`: only that machine (hardware, legacy choices)

Run `genesis apply` and `genesis save` in your own terminal: aconfmgr calls
`sudo` itself and needs to ask for your password.

## Hosts

A host is `hosts/<host>/archinstall.json` (stage 1 overrides, may be `{}`) plus
`aconfmgr/hosts/<host>.sh` (stage 2, optional). The hostname selects both.
Users and their groups for every host: `hosts/common/users` (`wheel` = admin).

New machine: run `genesis install` with a new name, then after `genesis apply`
on it, `genesis save` and put its specifics into `aconfmgr/hosts/<host>.sh`.

## Safety

- `aconfmgr/00-ignore.sh`: paths aconfmgr never captures or deletes (keys,
  credentials, accounts, machine state).
- `hooks/pre-commit`: refuses commits containing private paths or secret-looking
  content. Enabled automatically by any `genesis` command (`core.hooksPath=hooks`);
  CI also runs it on every push.

## Testing

```
pytest -q                                   # unit tests
shellcheck genesis hooks/pre-commit install/*.sh aconfmgr/*.sh aconfmgr/hosts/*.sh
```

Full VM test (needs `sudo pacman -S qemu-desktop edk2-ovmf` and an Arch ISO;
the VM clones from GitHub, so push your branch first):

1. `tests/vm/run.sh --iso archlinux-x86_64.iso`, then in the VM run the install
   steps above with host `vmtest`.
2. After install, power off and boot the disk: `tests/vm/run.sh`.
3. In the VM: `~/repos/genesis/genesis apply` succeeds; a second `genesis apply`
   reports `Done (system state unchanged)`.
4. Delete `tests/vm/work/` to start over.
