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
