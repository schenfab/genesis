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
