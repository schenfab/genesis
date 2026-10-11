# shellcheck shell=bash
# Per-host layer: aconfmgr/hosts/<hostname>.sh (aconfmgr does not source subdirectories itself).
# shellcheck disable=SC2154  # config_dir is set by aconfmgr
if [[ -f "$config_dir/hosts/$HOSTNAME.sh" ]]; then
	# shellcheck source=/dev/null
	source "$config_dir/hosts/$HOSTNAME.sh"
fi
