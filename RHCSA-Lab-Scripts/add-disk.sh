#!/usr/bin/env bash
set -euo pipefail
VM="${1:?usage: add-disk.sh <vm> <target-dev> <size-GB>}"
DEV="${2:?e.g. sdb}"
SIZE="${3:?e.g. 10}"

IMG="/home/libvirt/images/${VM}-${DEV}.qcow2"
echo "Creating ${SIZE}G disk for ${VM} as ${DEV}"
sudo qemu-img create -f qcow2 "${IMG}" "${SIZE}G"
sudo virsh attach-disk "${VM}" "${IMG}" "${DEV}" \
  --persistent --subdriver qcow2 --targetbus virtio
echo "Attached. Inside the VM it appears as /dev/${DEV}."
