#!/usr/bin/env bash
# Stage-2 users step. Usage: users.sh <users-file>
set -euo pipefail

while read -r user _groups; do
	[[ -z "$user" || "$user" == \#* ]] && continue
	if ! getent passwd "$user" >/dev/null; then
		echo "genesis: user '$user' does not exist, skipping" >&2
	fi
done < "$1"
