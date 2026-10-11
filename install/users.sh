#!/usr/bin/env bash
# Stage-2 users step. Usage: users.sh <users-file>
# Each line: "<user> <group>...". Creates missing groups as system groups and adds
# missing memberships. Never touches passwords (those are set during install).
set -euo pipefail

while read -r -a fields || [[ ${#fields[@]} -gt 0 ]]; do
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
