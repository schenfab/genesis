# genesis Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public repo that installs any of my Arch machines from the live ISO (archinstall) and keeps packages + `/etc` + services of every machine in sync with the repo (aconfmgr).

**Architecture:** `genesis` (bash) is the single entry point. `install` runs on the live ISO: Python (`install/archconf.py`) merges `hosts/common` + `hosts/<host>` archinstall JSON and builds a RAM-only credentials file, then archinstall's menu runs prefilled. `apply`/`save`/`check` wrap aconfmgr (git submodule, run from its checkout) with config dir `aconfmgr/`, plus a users step (`install/users.sh`). A pre-commit secret guard (also in CI) keeps private material out of the public repo.

**Tech Stack:** bash, Python 3 (stdlib only, ctypes → libcrypt), archinstall 4.x, aconfmgr (pinned submodule), pytest, shellcheck, GitHub Actions (archlinux container), QEMU + OVMF for the VM test.

**Spec:** `docs/superpowers/specs/2026-10-11-genesis-bootstrap-design.md`

## Global Constraints

- Arch Linux only. Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`, pass `shellcheck`, indent with tabs.
- Python: stdlib only (must run on the Arch live ISO's `python`).
- **Public repo: no secrets, not even password hashes.** Never commit files under the guarded paths in Task 1. Test fixtures that look like secrets must be built by string concatenation so the repo itself passes `hooks/pre-commit --all`.
- Users on every host: `fschenkel` (admin: `wheel`), `guest`, `andrea`. Passwords (root + users) are prompted at install time.
- Pinned stage-1 choices: locale `en_US.UTF-8` (+ `de_CH.UTF-8` generated), keymap `de_CH-latin1`, timezone `Europe/Zurich`, kernel `linux`, GNOME + gdm, PipeWire, NetworkManager, extra package `git`. Not pinned: disk, bootloader, swap/zram. Disk: user chooses default layout → btrfs → subvolumes → compression in the menu.
- aconfmgr must be invoked as `cd vendor/aconfmgr && ./aconfmgr -c <abs config dir> <action>` (it only runs "local mode" from inside its checkout). Pinned commit: `96ab414343b9467fca5ef46f04bc1bd1fc7bd8f1`.
- Run all tests with `pytest -q` from the repo root.

## File map

| Path | Responsibility |
|---|---|
| `hooks/pre-commit` | Secret guard: forbidden paths + secret-looking content; `--all` mode for CI |
| `genesis` | CLI dispatch: `install`, `apply`, `save`, `check` |
| `install/users.sh` | Stage-2 users step: ensure supplementary groups |
| `install/archconf.py` | Merge archinstall JSON, build hashed creds file |
| `install/bootstrap.sh` | Live-ISO glue: pick host, run archconf, launch archinstall |
| `hosts/common/archinstall.json`, `hosts/common/users` | Shared stage-1 config, user list |
| `hosts/<host>/archinstall.json` | Per-host stage-1 overrides (`moog`, `vmtest`) |
| `aconfmgr/*.sh`, `aconfmgr/hosts/*.sh`, `aconfmgr/files/` | aconfmgr config (common layers, host layer, stored files) |
| `vendor/aconfmgr` | aconfmgr submodule |
| `tests/` | pytest suite; `tests/vm/run.sh` VM launcher |
| `.github/workflows/ci.yml` | CI |
| `README.md`, `docs/post-install.md` | Workflow docs, manual private checklist |

---

### Task 1: Test scaffolding + secret guard

**Files:**
- Create: `tests/conftest.py`, `tests/test_secret_guard.py`, `hooks/pre-commit`, `.gitignore`

**Interfaces:**
- Produces: `tests/conftest.py` exports `REPO: Path` and `write_exe(path: Path, body: str) -> Path` (writes `#!/usr/bin/env bash\n` + body, chmod 755). `hooks/pre-commit [--all]` exits 0 clean / 1 with `secret guard: ...` lines on stderr.

- [ ] **Step 1: Write conftest and failing tests**

`tests/conftest.py`:
```python
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def write_exe(path: Path, body: str) -> Path:
    path.write_text("#!/usr/bin/env bash\n" + body)
    path.chmod(0o755)
    return path
```

`tests/test_secret_guard.py`:
```python
import subprocess

import pytest

from conftest import REPO

HOOK = REPO / "hooks" / "pre-commit"
# Built by concatenation so this file itself never trips the guard.
PRIVATE_KEY = "-----BEGIN " + "OPENSSH PRIVATE KEY-----\nabc\n"
OVPN_TAG = "<" + "key>\nabc\n</key>\n"
SHADOW_LINE = "root:" + "$" + "y$j9T$abcdefghijklmnopqrstuv:19000::\n"
PSK_LINE = "psk" + "=hunter2\n"


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "t@example.com")
    git(tmp_path, "config", "user.name", "t")
    return tmp_path


def stage(repo, rel, content):
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    git(repo, "add", rel)


def run_hook(repo, *args):
    return subprocess.run([str(HOOK), *args], cwd=repo, capture_output=True, text=True)


def test_clean_file_passes(repo):
    stage(repo, "aconfmgr/files/etc/nanorc", "set linenumbers\n")
    result = run_hook(repo)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize("rel", [
    "aconfmgr/files/etc/shadow",
    "aconfmgr/files/etc/gshadow-",
    "aconfmgr/files/etc/ssh/ssh_host_ed25519_key.pub",
    "aconfmgr/files/etc/docker/key.json",
    "aconfmgr/files/etc/docker/certs.d/registry/ca.crt",
    "aconfmgr/files/etc/openvpn/client/client.conf",
    "aconfmgr/files/etc/NetworkManager/system-connections/home.nmconnection",
    "aconfmgr/files/etc/ca-certificates/trust-source/work.p11-kit",
    "aconfmgr/files/etc/cups/ppd/printer.ppd",
])
def test_forbidden_path_rejected(repo, rel):
    stage(repo, rel, "harmless\n")
    result = run_hook(repo)
    assert result.returncode == 1
    assert rel in result.stderr


@pytest.mark.parametrize("content", [PRIVATE_KEY, OVPN_TAG, SHADOW_LINE, PSK_LINE])
def test_secret_content_rejected(repo, content):
    stage(repo, "aconfmgr/files/etc/something.conf", content)
    result = run_hook(repo)
    assert result.returncode == 1
    assert "aconfmgr/files/etc/something.conf" in result.stderr


def test_all_mode_checks_committed_files(repo):
    stage(repo, "notes.txt", PRIVATE_KEY)
    git(repo, "commit", "-q", "-m", "x")
    assert run_hook(repo).returncode == 0  # nothing staged
    assert run_hook(repo, "--all").returncode == 1


def test_this_repo_is_clean():
    result = run_hook(REPO, "--all")
    assert result.returncode == 0, result.stderr
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_secret_guard.py`
Expected: FAIL (`hooks/pre-commit` does not exist → `FileNotFoundError` / `PermissionError`).

- [ ] **Step 3: Implement the hook and .gitignore**

`hooks/pre-commit` (chmod 755):
```bash
#!/usr/bin/env bash
# Secret guard (this repo is public). Rejects private paths and secret-looking content.
#   hooks/pre-commit         check staged files (installed via core.hooksPath=hooks)
#   hooks/pre-commit --all   check every tracked file (CI)
set -euo pipefail

forbidden_paths=(
	'*/etc/shadow*' '*/etc/gshadow*' '*/etc/ssh/ssh_host_*'
	'*/etc/docker/key.json' '*/etc/docker/certs.d/*'
	'*/etc/openvpn/client/*' '*/etc/NetworkManager/system-connections/*'
	'*/etc/ca-certificates/trust-source/*' '*/etc/cups/ppd/*'
	'*/etc/credstore*' '*/etc/cryptsetup-keys.d/*'
)
# Written so that this file does not match itself.
secret_regex='-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----|BEGIN OpenVPN Static[ ]key|<(key|tls-auth|tls-crypt|secret)>|\$(y|gy|7|6|5|2[aby])\$[./A-Za-z0-9$]{16,}|^[[:space:]]*psk[[:space:]]*='

if [[ "${1:-}" == --all ]]; then
	# Skip gitlinks (submodules, mode 160000).
	mapfile -t files < <(git ls-files -s | awk -F'\t' '{ split($1, m, " "); if (m[1] != "160000") print $2 }')
	content() { cat -- "$1"; }
else
	mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR --ignore-submodules=all)
	content() { git show ":$1"; }
fi

failed=0
for f in "${files[@]}"; do
	for pat in "${forbidden_paths[@]}"; do
		# shellcheck disable=SC2053  # glob match is intended
		if [[ "/$f" == $pat ]]; then
			echo "secret guard: forbidden path: $f" >&2
			failed=1
			continue 2
		fi
	done
	if content "$f" | grep -qaE -- "$secret_regex"; then
		echo "secret guard: secret-looking content in: $f" >&2
		failed=1
	fi
done
exit "$failed"
```

`.gitignore`:
```
__pycache__/
.pytest_cache/
tests/vm/work/
*.iso
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `chmod +x hooks/pre-commit && pytest -q tests/test_secret_guard.py`
Expected: all PASS.

- [ ] **Step 5: Enable the hook locally and commit**

```bash
git config core.hooksPath hooks
git add .gitignore hooks/pre-commit tests/conftest.py tests/test_secret_guard.py
git commit -m "Add secret guard pre-commit hook and test scaffolding"
```

---

### Task 2: `genesis` CLI + aconfmgr submodule

**Files:**
- Create: `genesis`, `tests/test_genesis_cli.py`, `.gitmodules` (via `git submodule add`), `vendor/aconfmgr`
- Create (minimal stub, replaced in Task 3): `install/users.sh`, `hosts/common/users`

**Interfaces:**
- Consumes: `write_exe`, `REPO` from Task 1.
- Produces: `genesis <install|apply|save|check> [args]`. Env overrides (tests only): `GENESIS_ACONFMGR_DIR` (default `<root>/vendor/aconfmgr`), `GENESIS_USERS_FILE` (default `<root>/hosts/common/users`), `GENESIS_ISO_MARKER` (default `/run/archiso`). `apply` calls `install/users.sh <users_file>` after aconfmgr. `install` execs `install/bootstrap.sh "$@"` (created in Task 5).

- [ ] **Step 1: Add the submodule**

```bash
git submodule add https://github.com/CyberShadow/aconfmgr vendor/aconfmgr
git -C vendor/aconfmgr checkout 96ab414343b9467fca5ef46f04bc1bd1fc7bd8f1
git config -f .gitmodules submodule.vendor/aconfmgr.ignore dirty   # aconfmgr writes ./tmp inside its checkout
```

- [ ] **Step 2: Write failing tests**

`tests/test_genesis_cli.py`:
```python
import os
import subprocess

from conftest import REPO, write_exe

GENESIS = REPO / "genesis"


def make_env(tmp_path, **extra):
    fake = tmp_path / "fake-aconfmgr"
    fake.mkdir()
    write_exe(fake / "aconfmgr", 'echo "cwd=$PWD args=$*" >> "$GENESIS_TEST_LOG"\n')
    env = dict(os.environ, GENESIS_ACONFMGR_DIR=str(fake),
               GENESIS_TEST_LOG=str(tmp_path / "log"), **extra)
    return env, fake


def run(args, env):
    return subprocess.run([str(GENESIS), *args], env=env, capture_output=True, text=True)


def test_no_command_prints_usage(tmp_path):
    env, _ = make_env(tmp_path)
    result = run([], env)
    assert result.returncode == 2
    assert "Usage: genesis" in result.stderr


def test_unknown_command_fails(tmp_path):
    env, _ = make_env(tmp_path)
    assert run(["frobnicate"], env).returncode == 2


def test_save_runs_aconfmgr_from_its_checkout(tmp_path):
    env, fake = make_env(tmp_path)
    result = run(["save"], env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {REPO}/aconfmgr save\n"


def test_check_runs_aconfmgr_check(tmp_path):
    env, fake = make_env(tmp_path)
    assert run(["check"], env).returncode == 0
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {REPO}/aconfmgr check\n"


def test_apply_runs_aconfmgr_then_users_step(tmp_path):
    users = tmp_path / "users"
    users.write_text("genesis-no-such-user wheel\n")
    env, fake = make_env(tmp_path, GENESIS_USERS_FILE=str(users))
    result = run(["apply"], env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "log").read_text() == f"cwd={fake} args=-c {REPO}/aconfmgr apply\n"
    assert "genesis-no-such-user" in result.stderr  # users step ran and skipped unknown user


def test_install_refuses_outside_live_iso(tmp_path):
    env, _ = make_env(tmp_path, GENESIS_ISO_MARKER=str(tmp_path / "nope"))
    result = run(["install"], env)
    assert result.returncode == 1
    assert "live ISO" in result.stderr
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `pytest -q tests/test_genesis_cli.py`
Expected: FAIL (`genesis` missing).

- [ ] **Step 4: Implement `genesis` and the users-step stub**

`genesis` (chmod 755):
```bash
#!/usr/bin/env bash
# genesis: bootstrap and sync Arch Linux machines. See README.md.
set -euo pipefail

GENESIS_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ACONFMGR_DIR="${GENESIS_ACONFMGR_DIR:-$GENESIS_ROOT/vendor/aconfmgr}"
CONFIG_DIR="$GENESIS_ROOT/aconfmgr"
USERS_FILE="${GENESIS_USERS_FILE:-$GENESIS_ROOT/hosts/common/users}"
ISO_MARKER="${GENESIS_ISO_MARKER:-/run/archiso}"

usage() {
	cat >&2 <<'EOF'
Usage: genesis <command>
  install [host]  (live ISO only) install this machine with archinstall
  apply           make this machine match the repo (asks before every change)
  save            record this machine's drift into aconfmgr/99-unsorted.sh
  check           lint the aconfmgr config
EOF
	exit 2
}

die() { echo "genesis: $*" >&2; exit 1; }

run_aconfmgr() {
	if [[ ! -x "$ACONFMGR_DIR/aconfmgr" ]]; then
		git -C "$GENESIS_ROOT" submodule update --init vendor/aconfmgr
	fi
	# aconfmgr only works from inside its own checkout.
	(cd "$ACONFMGR_DIR" && ./aconfmgr -c "$CONFIG_DIR" "$@")
}

enable_secret_guard() {
	if git -C "$GENESIS_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
		git -C "$GENESIS_ROOT" config core.hooksPath hooks
	fi
}

[[ $# -ge 1 ]] || usage
command="$1"
shift

case "$command" in
	install)
		[[ -d "$ISO_MARKER" ]] || die "install must run from the Arch live ISO"
		exec "$GENESIS_ROOT/install/bootstrap.sh" "$@"
		;;
	apply)
		enable_secret_guard
		run_aconfmgr apply "$@"
		"$GENESIS_ROOT/install/users.sh" "$USERS_FILE"
		;;
	save)
		enable_secret_guard
		run_aconfmgr save "$@"
		if [[ -s "$CONFIG_DIR/99-unsorted.sh" ]]; then
			echo "genesis: new drift in aconfmgr/99-unsorted.sh; sort it into the common or host files, then commit." >&2
		fi
		;;
	check)
		enable_secret_guard
		run_aconfmgr check "$@"
		;;
	*)
		usage
		;;
esac
```

`install/users.sh` (chmod 755; minimal, Task 3 completes it):
```bash
#!/usr/bin/env bash
# Stage-2 users step. Usage: users.sh <users-file>
set -euo pipefail

while read -r user _groups; do
	[[ -z "$user" || "$user" == \#* ]] && continue
	if ! getent passwd "$user" >/dev/null; then
		echo "genesis: user '$user' does not exist, skipping" >&2
	fi
done < "$1"
```

`hosts/common/users`:
```
# <user> <supplementary groups...>
# Users in `wheel` are admins (sudo). Passwords are prompted at install, never stored here.
fschenkel wheel docker scanner uucp uinputg
guest
andrea
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `chmod +x genesis install/users.sh && pytest -q tests/test_genesis_cli.py`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add genesis install/users.sh hosts/common/users tests/test_genesis_cli.py .gitmodules vendor/aconfmgr
git commit -m "Add genesis CLI wrapping aconfmgr (pinned submodule)"
```

---

### Task 3: Users step (supplementary groups)

**Files:**
- Modify: `install/users.sh` (full implementation)
- Create: `tests/test_users.py`

**Interfaces:**
- Consumes: `hosts/common/users` format from Task 2: `<user> <group>...`, `#` comments, blank lines.
- Produces: `install/users.sh <users-file>`: for each existing user, creates missing groups with `sudo groupadd --system <g>`, adds missing memberships with `sudo usermod -aG <g> <user>`; warns and skips unknown users. Never touches passwords.

- [ ] **Step 1: Write failing tests**

`tests/test_users.py`:
```python
import os
import subprocess

from conftest import REPO, write_exe

USERS_SH = REPO / "install" / "users.sh"


def setup(tmp_path, users, groups, members):
    fake = tmp_path / "fake"
    fake.mkdir()
    (fake / "passwd").write_text("".join(f"{u}\n" for u in users))
    (fake / "group").write_text("".join(f"{g}\n" for g in groups))
    (fake / "members").write_text("".join(f"{u}:{' '.join(gs)}\n" for u, gs in members.items()))
    (fake / "log").write_text("")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    write_exe(bin_dir / "sudo", 'exec "$@"\n')
    write_exe(bin_dir / "getent", 'grep -qx -- "$2" "$FAKE/$1"\n')
    write_exe(bin_dir / "id", '[[ $1 == -nG ]]; grep "^$2:" "$FAKE/members" | cut -d: -f2\n')
    write_exe(bin_dir / "groupadd", 'echo "groupadd $*" >> "$FAKE/log"; echo "${*: -1}" >> "$FAKE/group"\n')
    write_exe(bin_dir / "usermod", 'echo "usermod $*" >> "$FAKE/log"\n')
    env = dict(os.environ, FAKE=str(fake), PATH=f"{bin_dir}:{os.environ['PATH']}")
    return fake, env


def run(tmp_path, env, users_file_text):
    users_file = tmp_path / "users"
    users_file.write_text(users_file_text)
    return subprocess.run([str(USERS_SH), str(users_file)], env=env, capture_output=True, text=True)


def test_adds_missing_membership(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], ["docker"], {"fschenkel": ["fschenkel"]})
    result = run(tmp_path, env, "fschenkel docker\n")
    assert result.returncode == 0, result.stderr
    assert (fake / "log").read_text() == "usermod -aG docker fschenkel\n"


def test_existing_membership_is_left_alone(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], ["docker"], {"fschenkel": ["fschenkel", "docker"]})
    assert run(tmp_path, env, "fschenkel docker\n").returncode == 0
    assert (fake / "log").read_text() == ""


def test_missing_group_is_created_as_system_group(tmp_path):
    fake, env = setup(tmp_path, ["fschenkel"], [], {"fschenkel": ["fschenkel"]})
    assert run(tmp_path, env, "fschenkel uinputg\n").returncode == 0
    assert (fake / "log").read_text() == "groupadd --system uinputg\nusermod -aG uinputg fschenkel\n"


def test_unknown_user_is_skipped_with_warning(tmp_path):
    fake, env = setup(tmp_path, [], ["docker"], {})
    result = run(tmp_path, env, "ghost docker\n")
    assert result.returncode == 0
    assert "ghost" in result.stderr
    assert (fake / "log").read_text() == ""


def test_comments_blank_lines_and_groupless_users(tmp_path):
    fake, env = setup(tmp_path, ["guest"], [], {"guest": ["guest"]})
    assert run(tmp_path, env, "# comment\n\nguest\n").returncode == 0
    assert (fake / "log").read_text() == ""
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_users.py`
Expected: `test_adds_missing_membership` and `test_missing_group_is_created_as_system_group` FAIL (stub does nothing).

- [ ] **Step 3: Implement**

`install/users.sh`:
```bash
#!/usr/bin/env bash
# Stage-2 users step. Usage: users.sh <users-file>
# Each line: "<user> <group>...". Creates missing groups as system groups and adds
# missing memberships. Never touches passwords (those are set during install).
set -euo pipefail

while read -r -a fields; do
	[[ ${#fields[@]} -eq 0 || "${fields[0]}" == \#* ]] && continue
	user="${fields[0]}"
	if ! getent passwd "$user" >/dev/null; then
		echo "genesis: user '$user' does not exist, skipping" >&2
		continue
	fi
	for group in "${fields[@]:1}"; do
		getent group "$group" >/dev/null || sudo groupadd --system "$group"
		if ! id -nG "$user" | tr ' ' '\n' | grep -qx -- "$group"; then
			sudo usermod -aG "$group" "$user"
		fi
	done
done < "$1"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q tests/test_users.py tests/test_genesis_cli.py`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add install/users.sh tests/test_users.py
git commit -m "Implement users step: ensure supplementary groups"
```

---

### Task 4: `archconf.py` (archinstall config + credentials)

**Files:**
- Create: `install/archconf.py`, `tests/test_archconf.py`, `hosts/common/archinstall.json`, `hosts/moog/archinstall.json`, `hosts/vmtest/archinstall.json`

**Interfaces:**
- Consumes: `hosts/common/users` format (Task 2).
- Produces (module functions):
  - `deep_merge(base: dict, override: dict) -> dict`: dicts merge recursively; keys in `ADDITIVE_KEYS = {"packages", "custom_commands"}` concatenate lists; everything else is replaced.
  - `load_users(path: Path) -> list[tuple[str, list[str]]]`
  - `build_config(hosts_dir: Path, host: str, repo_url: str, repo_ref: str) -> dict`: merged config with `hostname=host`; appends a custom command cloning the repo (with submodules) to `/home/<first wheel user>/repos/genesis` owned by that user.
  - `hash_password(password: str) -> str` (yescrypt `$y$…`), `_crypt(password: str, setting: str) -> str`
  - `ask_password(label: str, read) -> str`: asks twice until non-empty and equal.
  - `build_creds(users, read) -> dict`: `{"root_enc_password": h, "users": [{"username", "enc_password", "sudo", "groups": []}]}`; `sudo` is true iff `wheel` in the user's groups.
  - `write_private_json(path: Path, data: dict) -> None` (mode 0600)
  - CLI: `archconf.py config <hosts_dir> <host> <repo_url> <repo_ref>` prints JSON; `archconf.py creds <users_file> <out_path>` prompts (getpass on a TTY, unbuffered line reads from fd 0 otherwise) and writes the creds file.

- [ ] **Step 1: Write host config files**

`hosts/common/archinstall.json`:
```json
{
  "locale_config": {"kb_layout": "de_CH-latin1", "sys_lang": "en_US.UTF-8", "sys_enc": "UTF-8"},
  "timezone": "Europe/Zurich",
  "kernels": ["linux"],
  "ntp": true,
  "profile_config": {
    "profile": {"main": "Desktop", "details": ["GNOME"]},
    "greeter": "gdm",
    "gfx_driver": "All open-source"
  },
  "app_config": {"audio_config": {"audio": "pipewire"}},
  "network_config": {"type": "nm"},
  "packages": ["git"],
  "custom_commands": [
    "sed -i 's/^#de_CH.UTF-8 UTF-8/de_CH.UTF-8 UTF-8/' /etc/locale.gen && locale-gen"
  ]
}
```

`hosts/moog/archinstall.json` and `hosts/vmtest/archinstall.json`:
```json
{}
```

- [ ] **Step 2: Write failing tests**

`tests/test_archconf.py`:
```python
import json
import os
import stat
import subprocess
import sys

import pytest

from conftest import REPO

sys.path.insert(0, str(REPO / "install"))
import archconf  # noqa: E402

ARCHCONF = REPO / "install" / "archconf.py"


def test_deep_merge_nested_and_scalars():
    base = {"a": {"x": 1, "y": 2}, "s": "base", "kernels": ["linux"]}
    over = {"a": {"y": 3}, "s": "over", "kernels": ["linux-lts"]}
    assert archconf.deep_merge(base, over) == {"a": {"x": 1, "y": 3}, "s": "over", "kernels": ["linux-lts"]}


def test_deep_merge_additive_keys_concatenate():
    base = {"packages": ["git"], "custom_commands": ["a"]}
    over = {"packages": ["vim"], "custom_commands": ["b"]}
    assert archconf.deep_merge(base, over) == {"packages": ["git", "vim"], "custom_commands": ["a", "b"]}


def test_deep_merge_does_not_mutate_inputs():
    base = {"a": {"x": 1}}
    archconf.deep_merge(base, {"a": {"x": 2}})
    assert base == {"a": {"x": 1}}


def test_load_users(tmp_path):
    f = tmp_path / "users"
    f.write_text("# c\n\nfschenkel wheel docker\nguest\n")
    assert archconf.load_users(f) == [("fschenkel", ["wheel", "docker"]), ("guest", [])]


def write_hosts(tmp_path, host_json=None):
    hosts = tmp_path / "hosts"
    (hosts / "common").mkdir(parents=True)
    (hosts / "common" / "archinstall.json").write_text(json.dumps(
        {"timezone": "Europe/Zurich", "packages": ["git"], "custom_commands": ["locale-gen"]}))
    (hosts / "common" / "users").write_text("fschenkel wheel\nguest\n")
    if host_json is not None:
        (hosts / "box").mkdir()
        (hosts / "box" / "archinstall.json").write_text(json.dumps(host_json))
    return hosts


def test_build_config_merges_host_and_sets_hostname(tmp_path):
    hosts = write_hosts(tmp_path, {"packages": ["vim"], "timezone": "UTC"})
    cfg = archconf.build_config(hosts, "box", "https://github.com/me/genesis.git", "main")
    assert cfg["hostname"] == "box"
    assert cfg["timezone"] == "UTC"
    assert cfg["packages"] == ["git", "vim"]
    assert cfg["custom_commands"][0] == "locale-gen"
    clone = cfg["custom_commands"][-1]
    assert "git clone --recurse-submodules --branch main https://github.com/me/genesis.git /home/fschenkel/repos/genesis" in clone
    assert "chown -R fschenkel:fschenkel /home/fschenkel/repos" in clone


def test_build_config_new_host_uses_common_only(tmp_path):
    hosts = write_hosts(tmp_path)
    cfg = archconf.build_config(hosts, "newbox", "https://x/g.git", "main")
    assert cfg["hostname"] == "newbox"
    assert cfg["packages"] == ["git"]


def test_real_common_config_is_valid_json_and_pins_choices():
    cfg = archconf.build_config(REPO / "hosts", "moog", "https://x/g.git", "main")
    assert cfg["locale_config"]["kb_layout"] == "de_CH-latin1"
    assert cfg["network_config"] == {"type": "nm"}
    assert "disk_config" not in cfg and "bootloader_config" not in cfg


def test_hash_password_is_yescrypt_and_verifies():
    h = archconf.hash_password("s3cret")
    assert h.startswith("$y$")
    assert archconf._crypt("s3cret", h) == h
    assert archconf._crypt("wrong", h) != h


def test_ask_password_repeats_until_match():
    answers = iter(["a", "b", "", "", "pw", "pw"])
    assert archconf.ask_password("root", lambda prompt: next(answers)) == "pw"


def test_build_creds_structure():
    answers = iter(["r", "r", "f", "f", "g", "g"])
    creds = archconf.build_creds([("fschenkel", ["wheel"]), ("guest", [])], lambda p: next(answers))
    assert archconf._crypt("r", creds["root_enc_password"]) == creds["root_enc_password"]
    assert [(u["username"], u["sudo"], u["groups"]) for u in creds["users"]] == [
        ("fschenkel", True, []), ("guest", False, [])]
    assert archconf._crypt("g", creds["users"][1]["enc_password"]) == creds["users"][1]["enc_password"]


def test_write_private_json_mode_0600(tmp_path):
    out = tmp_path / "creds.json"
    archconf.write_private_json(out, {"a": 1})
    assert stat.S_IMODE(out.stat().st_mode) == 0o600
    assert json.loads(out.read_text()) == {"a": 1}


def test_cli_creds_reads_non_tty_stdin(tmp_path):
    users = tmp_path / "users"
    users.write_text("fschenkel wheel\n")
    out = tmp_path / "creds.json"
    result = subprocess.run([sys.executable, str(ARCHCONF), "creds", str(users), str(out)],
                            input="r\nr\nf\nf\nREST\n", capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert [u["username"] for u in json.loads(out.read_text())["users"]] == ["fschenkel"]


def test_cli_creds_does_not_consume_extra_stdin(tmp_path):
    """bootstrap.sh reads an Enter keypress from the same stdin after archconf."""
    users = tmp_path / "users"
    users.write_text("fschenkel wheel\n")
    script = f'"{sys.executable}" "{ARCHCONF}" creds "{users}" "{tmp_path}/c.json"; read -r rest; echo "rest=$rest"'
    result = subprocess.run(["bash", "-c", script], input="r\nr\nf\nf\nREST\n", capture_output=True, text=True)
    assert "rest=REST" in result.stdout


def test_cli_config_prints_json():
    result = subprocess.run([sys.executable, str(ARCHCONF), "config", str(REPO / "hosts"), "moog",
                             "https://x/g.git", "main"], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["hostname"] == "moog"
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `pytest -q tests/test_archconf.py`
Expected: FAIL (`ModuleNotFoundError: archconf`).

- [ ] **Step 4: Implement**

`install/archconf.py` (chmod 755):
```python
#!/usr/bin/env python
"""Build archinstall config and credentials for a genesis host.

  archconf.py config <hosts_dir> <host> <repo_url> <repo_ref>   print merged config JSON
  archconf.py creds <users_file> <out_path>                     prompt passwords, write creds JSON (0600)
"""
import ctypes
import ctypes.util
import getpass
import json
import os
import shlex
import sys
from pathlib import Path

ADDITIVE_KEYS = {"packages", "custom_commands"}


def deep_merge(base, override):
    merged = dict(base)
    for key, value in override.items():
        if key in ADDITIVE_KEYS and isinstance(merged.get(key), list):
            merged[key] = merged[key] + list(value)
        elif isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_users(path):
    users = []
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#"):
            users.append((fields[0], fields[1:]))
    return users


def build_config(hosts_dir, host, repo_url, repo_ref):
    hosts_dir = Path(hosts_dir)
    config = json.loads((hosts_dir / "common" / "archinstall.json").read_text())
    host_file = hosts_dir / host / "archinstall.json"
    if host_file.exists():
        config = deep_merge(config, json.loads(host_file.read_text()))
    config["hostname"] = host
    admin = next(name for name, groups in load_users(hosts_dir / "common" / "users") if "wheel" in groups)
    repos = f"/home/{admin}/repos"
    clone = (f"git clone --recurse-submodules --branch {shlex.quote(repo_ref)} "
             f"{shlex.quote(repo_url)} {repos}/genesis && chown -R {admin}:{admin} {repos}")
    config["custom_commands"] = config.get("custom_commands", []) + [clone]
    return config


def _libcrypt():
    lib = ctypes.CDLL(ctypes.util.find_library("crypt") or "libcrypt.so.2")
    lib.crypt_gensalt.restype = ctypes.c_char_p
    lib.crypt_gensalt.argtypes = [ctypes.c_char_p, ctypes.c_ulong, ctypes.c_char_p, ctypes.c_int]
    lib.crypt.restype = ctypes.c_char_p
    lib.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    return lib


def _crypt(password, setting):
    out = _libcrypt().crypt(password.encode(), setting.encode())
    if not out or out.startswith(b"*"):
        raise RuntimeError("crypt() failed")
    return out.decode()


def hash_password(password):
    salt = _libcrypt().crypt_gensalt(b"$y$", 0, None, 0)
    if not salt:
        raise RuntimeError("crypt_gensalt() failed")
    return _crypt(password, salt.decode())


def ask_password(label, read):
    while True:
        first = read(f"Password for {label}: ")
        second = read(f"Repeat password for {label}: ")
        if first and first == second:
            return first
        print("Passwords empty or not matching, try again.", file=sys.stderr)


def build_creds(users, read):
    return {
        "root_enc_password": hash_password(ask_password("root", read)),
        "users": [
            {"username": name, "enc_password": hash_password(ask_password(name, read)),
             "sudo": "wheel" in groups, "groups": []}
            for name, groups in users
        ],
    }


def write_private_json(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)


def _read_line_unbuffered(prompt):
    """Read one line from fd 0 without consuming more (the caller's shell reads after us)."""
    print(prompt, end="", file=sys.stderr, flush=True)
    chars = []
    while True:
        c = os.read(0, 1)
        if not c:
            raise EOFError("stdin closed while reading password")
        if c == b"\n":
            return b"".join(chars).decode()
        chars.append(c)


def main(argv):
    if len(argv) == 5 and argv[0] == "config":
        json.dump(build_config(Path(argv[1]), argv[2], argv[3], argv[4]), sys.stdout, indent=2)
        print()
    elif len(argv) == 3 and argv[0] == "creds":
        read = getpass.getpass if sys.stdin.isatty() else _read_line_unbuffered
        write_private_json(Path(argv[2]), build_creds(load_users(Path(argv[1])), read))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `chmod +x install/archconf.py && pytest -q tests/test_archconf.py`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add install/archconf.py tests/test_archconf.py hosts/
git commit -m "Add archinstall config merge and RAM-only credentials builder"
```

---

### Task 5: `bootstrap.sh` (live ISO glue)

**Files:**
- Create: `install/bootstrap.sh`, `tests/test_bootstrap.py`

**Interfaces:**
- Consumes: `archconf.py config|creds` (Task 4), `hosts/` (Task 4), `genesis install` execs this (Task 2).
- Produces: `install/bootstrap.sh [host]`. Env overrides (tests only): `GENESIS_ARCHINSTALL` (default `archinstall`), `GENESIS_REPO_URL` (default: origin URL, `git@github.com:` rewritten to `https://github.com/`), `GENESIS_REPO_REF` (default: current branch). Temp dir is removed on exit.

- [ ] **Step 1: Write failing tests**

`tests/test_bootstrap.py`:
```python
import json
import os
import subprocess
from pathlib import Path

from conftest import REPO, write_exe

BOOTSTRAP = REPO / "install" / "bootstrap.sh"
# root, fschenkel, guest, andrea, each entered twice; then Enter to start archinstall
STDIN = "r\nr\nf\nf\ng\ng\na\na\n\n"


def make_env(tmp_path):
    capture = tmp_path / "capture"
    capture.mkdir()
    stub = write_exe(tmp_path / "archinstall", (
        'while [[ $# -gt 0 ]]; do case $1 in\n'
        '  --config) cp "$2" "$CAPTURE/config.json"; echo "$2" > "$CAPTURE/config.path"; shift 2;;\n'
        '  --creds) cp "$2" "$CAPTURE/creds.json"; echo "$2" > "$CAPTURE/creds.path"; shift 2;;\n'
        '  *) echo "unexpected arg $1" >&2; exit 9;;\n'
        'esac; done\n'))
    env = dict(os.environ, CAPTURE=str(capture), GENESIS_ARCHINSTALL=str(stub),
               GENESIS_REPO_URL="https://github.com/me/genesis.git", GENESIS_REPO_REF="main")
    return capture, env


def test_bootstrap_builds_config_and_creds_and_cleans_up(tmp_path):
    capture, env = make_env(tmp_path)
    result = subprocess.run([str(BOOTSTRAP), "moog"], input=STDIN, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    config = json.loads((capture / "config.json").read_text())
    creds = json.loads((capture / "creds.json").read_text())
    assert config["hostname"] == "moog"
    assert "https://github.com/me/genesis.git" in config["custom_commands"][-1]
    assert [u["username"] for u in creds["users"]] == ["fschenkel", "guest", "andrea"]
    assert not Path((capture / "creds.path").read_text().strip()).exists()  # temp creds deleted
    assert "btrfs" in result.stdout  # disk instructions shown


def test_bootstrap_rejects_invalid_host_name(tmp_path):
    _, env = make_env(tmp_path)
    result = subprocess.run([str(BOOTSTRAP), "Bad Name"], input=STDIN, env=env, capture_output=True, text=True)
    assert result.returncode == 1
    assert "invalid host name" in result.stderr
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_bootstrap.py`
Expected: FAIL (`bootstrap.sh` missing).

- [ ] **Step 3: Implement**

`install/bootstrap.sh` (chmod 755):
```bash
#!/usr/bin/env bash
# Stage 1 on the Arch live ISO (via `genesis install [host]`): build the archinstall
# config for a host, prompt for passwords, then launch archinstall's prefilled menu.
set -euo pipefail

GENESIS_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
HOSTS_DIR="$GENESIS_ROOT/hosts"
ARCHCONF="$GENESIS_ROOT/install/archconf.py"
ARCHINSTALL="${GENESIS_ARCHINSTALL:-archinstall}"

host="${1:-}"
if [[ -z "$host" ]]; then
	echo "Known hosts:"
	for dir in "$HOSTS_DIR"/*/; do
		name="$(basename "$dir")"
		[[ "$name" == common ]] || echo "  $name"
	done
	read -rp "Host name (a new name gets the common defaults only): " host
fi
if [[ ! "$host" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
	echo "genesis: invalid host name: '$host'" >&2
	exit 1
fi

repo_url="${GENESIS_REPO_URL:-$(git -C "$GENESIS_ROOT" remote get-url origin)}"
repo_url="${repo_url/#git@github.com:/https://github.com/}"
repo_ref="${GENESIS_REPO_REF:-$(git -C "$GENESIS_ROOT" rev-parse --abbrev-ref HEAD)}"

workdir="$(mktemp -d)" # /tmp on the live ISO is RAM-backed
trap 'rm -rf "$workdir"' EXIT

python "$ARCHCONF" config "$HOSTS_DIR" "$host" "$repo_url" "$repo_ref" > "$workdir/config.json"
echo "Set passwords (stored only as hashes in RAM, handed to archinstall, then deleted):"
python "$ARCHCONF" creds "$HOSTS_DIR/common/users" "$workdir/creds.json"

cat <<EOF

Next, archinstall opens with host '$host' prefilled. In its menu:
  1. Disk configuration -> default (best-effort) partition layout -> select the target disk
     -> filesystem: btrfs -> default subvolume structure: yes -> compression: yes
  2. Leave bootloader and swap at archinstall's defaults.
  3. Review the remaining entries, then choose Install.
After the reboot, log in as the admin user and run:  ~/repos/genesis/genesis apply
EOF
read -rp "Press Enter to start archinstall..."

"$ARCHINSTALL" --config "$workdir/config.json" --creds "$workdir/creds.json"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `chmod +x install/bootstrap.sh && pytest -q`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add install/bootstrap.sh tests/test_bootstrap.py
git commit -m "Add live-ISO bootstrap launching prefilled archinstall"
```

---

### Task 6: aconfmgr config skeleton (ignore list, layers, host sourcing)

**Files:**
- Create: `aconfmgr/00-ignore.sh`, `aconfmgr/10-base.sh`, `aconfmgr/20-desktop.sh`, `aconfmgr/30-dev.sh`, `aconfmgr/50-host.sh`, `aconfmgr/hosts/moog.sh`, `aconfmgr/hosts/vmtest.sh`, `tests/test_aconfmgr_config.py`

**Interfaces:**
- Consumes: aconfmgr helpers (`IgnorePath PATTERN...`, `AddPackage [--foreign] PKG...`, `CopyFile PATH [MODE]`, `CopyFileTo SRC DST`, `CreateLink PATH TARGET`), variables `$config_dir`, `$HOSTNAME`.
- Produces: `50-host.sh` sources `$config_dir/hosts/$HOSTNAME.sh` if it exists. Host files live in `aconfmgr/hosts/<host>.sh`; host-only stored files go under `aconfmgr/files/` at their real path, or under `aconfmgr/files/hosts/<host>/…` with `CopyFileTo "/hosts/<host>/<path>" "<path>"` when the path is also used by a common layer.

- [ ] **Step 1: Write failing tests**

`tests/test_aconfmgr_config.py`:
```python
import shutil
import subprocess

import pytest

from conftest import REPO

CONFIG = REPO / "aconfmgr"
STUBS = 'AddPackage(){ echo "AddPackage $*"; }; IgnorePath(){ :; }; '


def source_host_layer(config_dir, hostname):
    script = STUBS + f'config_dir="{config_dir}"; HOSTNAME="{hostname}"; source "$config_dir/50-host.sh"'
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True).stdout


def test_host_layer_sources_matching_host_file(tmp_path):
    (tmp_path / "hosts").mkdir()
    shutil.copy(CONFIG / "50-host.sh", tmp_path)
    (tmp_path / "hosts" / "box.sh").write_text("AddPackage only-on-box\n")
    assert source_host_layer(tmp_path, "box") == "AddPackage only-on-box\n"
    assert source_host_layer(tmp_path, "other") == ""


@pytest.mark.parametrize("script", sorted(CONFIG.glob("*.sh")) + sorted(CONFIG.glob("hosts/*.sh")),
                         ids=lambda p: p.name)
def test_config_scripts_parse(script):
    subprocess.run(["bash", "-n", str(script)], check=True)


def test_every_guarded_path_is_ignored():
    """Paths the secret guard forbids must also be ignored by aconfmgr (so save never captures them)."""
    ignore = (CONFIG / "00-ignore.sh").read_text()
    for path in ["/etc/shadow", "/etc/gshadow", "/etc/ssh/ssh_host_", "/etc/docker/key.json",
                 "/etc/docker/certs.d", "/etc/openvpn/client", "/etc/NetworkManager/system-connections",
                 "/etc/ca-certificates/trust-source", "/etc/cups/ppd", "/etc/credstore",
                 "/etc/cryptsetup-keys.d"]:
        assert f"'{path}" in ignore, path
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q tests/test_aconfmgr_config.py`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement config files**

`aconfmgr/00-ignore.sh`:
```bash
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
```

`aconfmgr/10-base.sh`:
```bash
# shellcheck shell=bash
# Common to every host: base system, pacman, shell tools, ssh, printing/scanning daemons.
```

`aconfmgr/20-desktop.sh`:
```bash
# shellcheck shell=bash
# Common to every host: GNOME desktop, audio, fonts, desktop applications.
```

`aconfmgr/30-dev.sh`:
```bash
# shellcheck shell=bash
# Common to every host: development tools, containers, SDKs.
```

`aconfmgr/50-host.sh`:
```bash
# shellcheck shell=bash
# Per-host layer: aconfmgr/hosts/<hostname>.sh (aconfmgr does not source subdirectories itself).
# shellcheck disable=SC2154  # config_dir is set by aconfmgr
if [[ -f "$config_dir/hosts/$HOSTNAME.sh" ]]; then
	# shellcheck source=/dev/null
	source "$config_dir/hosts/$HOSTNAME.sh"
fi
```

`aconfmgr/hosts/moog.sh`:
```bash
# shellcheck shell=bash
# moog: Dell OptiPlex 790 (legacy BIOS, GRUB, ext4, dhcpcd), AMD RX 460, Logitech G15.
```

`aconfmgr/hosts/vmtest.sh`:
```bash
# shellcheck shell=bash
# vmtest: QEMU/OVMF test VM (see tests/vm/run.sh). Common layers only.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add aconfmgr/ tests/test_aconfmgr_config.py
git commit -m "Add aconfmgr config skeleton with ignore list and host layer"
```

---

### Task 7: CI, README, post-install checklist, VM launcher

**Files:**
- Create: `.github/workflows/ci.yml`, `README.md`, `docs/post-install.md`, `tests/vm/run.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: `tests/vm/run.sh [--iso PATH]` (creates `tests/vm/work/{disk.qcow2,OVMF_VARS.4m.fd}` on first run).

- [ ] **Step 1: Install local lint tool and lint**

User runs (sudo): `sudo pacman -S --needed shellcheck`
Run: `shellcheck genesis hooks/pre-commit install/*.sh aconfmgr/*.sh aconfmgr/hosts/*.sh`
Expected: no output. Fix any finding before continuing.

- [ ] **Step 2: Write CI workflow**

`.github/workflows/ci.yml`:
```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - run: pacman -Syu --noconfirm --needed git python python-pytest shellcheck
      - uses: actions/checkout@v4
        with:
          submodules: true
      - run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
      - run: hooks/pre-commit --all
      - run: shellcheck genesis hooks/pre-commit install/*.sh aconfmgr/*.sh aconfmgr/hosts/*.sh
      - run: pytest -q
```

- [ ] **Step 3: Write VM launcher**

`tests/vm/run.sh` (chmod 755):
```bash
#!/usr/bin/env bash
# Boot the genesis test VM (UEFI via OVMF). First run: tests/vm/run.sh --iso archlinux-x86_64.iso
# Later runs (boot installed disk): tests/vm/run.sh
set -euo pipefail

work="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/work"
ovmf_code=/usr/share/edk2/x64/OVMF_CODE.4m.fd
ovmf_vars=/usr/share/edk2/x64/OVMF_VARS.4m.fd

iso_args=()
if [[ "${1:-}" == --iso ]]; then
	[[ -f "${2:-}" ]] || { echo "usage: $0 [--iso PATH]" >&2; exit 2; }
	iso_args=(-drive "file=$2,media=cdrom,readonly=on")
fi

mkdir -p "$work"
[[ -f "$work/disk.qcow2" ]] || qemu-img create -f qcow2 "$work/disk.qcow2" 40G
[[ -f "$work/OVMF_VARS.4m.fd" ]] || cp "$ovmf_vars" "$work/OVMF_VARS.4m.fd"

exec qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 4096 \
	-drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" \
	-drive "if=pflash,format=raw,file=$work/OVMF_VARS.4m.fd" \
	-drive "file=$work/disk.qcow2,if=virtio,format=qcow2" \
	"${iso_args[@]}" \
	-nic user,model=virtio-net-pci -vga virtio -display gtk
```

- [ ] **Step 4: Write `docs/post-install.md`**

```markdown
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
```

- [ ] **Step 5: Write `README.md`**

````markdown
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
````

- [ ] **Step 6: Verify and commit**

Run: `chmod +x tests/vm/run.sh && shellcheck tests/vm/run.sh && pytest -q && hooks/pre-commit --all`
Expected: no shellcheck output, all tests PASS, guard exit 0.

```bash
git add .github/workflows/ci.yml README.md docs/post-install.md tests/vm/run.sh
git commit -m "Add CI, README with live-ISO workflow, post-install checklist, VM launcher"
```

- [ ] **Step 7: Push and confirm CI is green**

```bash
git push
gh run watch --exit-status
```
Expected: CI job succeeds.

---

### Task 8: Initial capture from moog (interactive, with the user)

No new code; fills `aconfmgr/` with moog's real state. Each `genesis` command here is run **by the user in their own terminal** (sudo prompts); Claude reads the results and sorts.

**Sorting rules:**
- Common (`10-base`/`20-desktop`/`30-dev`): anything I want on every machine.
- `hosts/moog.sh`: hardware- or legacy-specific: `grub`, `dhcpcd`, `ntpdate` (+ its `hwclock.conf` drop-in), `g15daemon*`, `hplip-plugin`, the `/swap` swapfile, `amdgpu` options, `/etc/default/grub`, `latarcyrheb-sun32` console font, moog's `dhcpcd`/`resolv.conf` and anything tied to moog's devices (udev rules for specific hardware).
- Delete instead of keeping: `*.O`, `resolv.conf.bak`, `fstab~`, stale `.pacnew`/`.pacsave`.
- Private → add to `00-ignore.sh` (and `hooks/pre-commit` + its test if it's a new class of secret) and `docs/post-install.md`.

- [ ] **Step 1: User runs first save**

User: `~/repos/genesis/genesis save`
Expected: `aconfmgr/99-unsorted.sh` and `aconfmgr/files/` populated.

- [ ] **Step 2: Review for noise and secrets before anything else**

Run: `git status --short aconfmgr/ && wc -l aconfmgr/99-unsorted.sh && hooks/pre-commit --all; git add -N aconfmgr && hooks/pre-commit`
Expected: guard exit 0. For every noisy path family (caches, generated files), add an `IgnorePath` to `00-ignore.sh`, delete the corresponding lines/files, and have the user re-run `genesis save` until `99-unsorted.sh` contains only real configuration.

- [ ] **Step 3: Move kernel parameter to modprobe**

Add to `aconfmgr/hosts/moog.sh`:
```bash
CopyFile /etc/modprobe.d/amdgpu.conf
```
and create `aconfmgr/files/etc/modprobe.d/amdgpu.conf`:
```
# Disable runtime power management (screen/GPU issues on moog's RX 460).
options amdgpu runpm=0
```
(The existing `amdgpu.runpm=0` in `/etc/default/grub` stays captured as-is in moog's GRUB config; both are harmless together.)

- [ ] **Step 4: Sort `99-unsorted.sh` into the layer files**

Move every line per the sorting rules; for files used only by moog keep `CopyFile <path>` in `hosts/moog.sh`. Delete `99-unsorted.sh`. Run `pytest -q && shellcheck aconfmgr/*.sh aconfmgr/hosts/*.sh && hooks/pre-commit --all`.
Expected: all pass.

- [ ] **Step 5: User verifies moog is in sync**

User: `~/repos/genesis/genesis save`, expected: no `99-unsorted.sh` created (`Done (configuration unchanged)`).
User: `~/repos/genesis/genesis apply`, expected: `Done (system state unchanged)` (only the new `amdgpu.conf` may be installed on the first run; answer yes, then re-run to see unchanged).

- [ ] **Step 6: Commit and push**

```bash
git add aconfmgr/ docs/post-install.md
git commit -m "Capture moog: packages, /etc and services sorted into common and host layers"
git push
```

---

### Task 9: End-to-end VM test

- [ ] **Step 1: User installs VM tooling and fetches the ISO**

User: `sudo pacman -S --needed qemu-desktop edk2-ovmf`
User: download the current ISO from https://archlinux.org/download/ into the repo root (ignored by `.gitignore`) and verify its checksum per that page.

- [ ] **Step 2: Install**

User: `tests/vm/run.sh --iso archlinux-x86_64.iso`; in the VM follow README "Install a machine" with host `vmtest`.
Expected: archinstall completes; VM reboots into GDM. Check `findmnt -no FSTYPE /` prints `btrfs`, and `/home/fschenkel/repos/genesis` exists, owned by fschenkel.

- [ ] **Step 3: Apply**

User (in VM): `~/repos/genesis/genesis apply`, answer yes.
Expected: completes without errors (AUR builds succeed). Second run: `Done (system state unchanged)`. `id fschenkel` lists docker, scanner, uucp, uinputg.

- [ ] **Step 4: Record results**

Any failure → fix in a task-sized change with a test where possible (e.g. new ignore entry, archinstall key change), re-run from Step 2 if stage 1 changed. When green, note the archinstall ISO version tested in README "Testing" and commit:
```bash
git add README.md
git commit -m "Document VM-tested archinstall version"
git push
```
