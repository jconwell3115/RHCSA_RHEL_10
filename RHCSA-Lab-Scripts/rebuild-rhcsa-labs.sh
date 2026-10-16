#!/usr/bin/env bash
# rebuild-rhcsa-labs.sh — full teardown + rebuild of all three exam environments
set -euo pipefail

POOL=/home/libvirt/images
ADDDISK="$(dirname "$(readlink -f "$0")")/add-disk.sh"   # sibling script, wherever the repo is cloned

teardown() {
  for vm in "$@"; do
    sudo virsh destroy "${vm}" 2>/dev/null || true
    sudo virsh undefine "${vm}" --remove-all-storage --snapshots-metadata 2>/dev/null || true
  done
}

echo "== Tearing down existing exam VMs =="
teardown rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta rhel10-echo rhel10-foxtrot

echo "== Cloning Exam 1 VMs =="
sudo virt-clone --original rhel10-golden --name rhel10-alpha --file ${POOL}/rhel10-alpha.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-bravo --file ${POOL}/rhel10-bravo.qcow2

echo "== Cloning Exam 2 VMs =="
sudo virt-clone --original rhel10-golden --name rhel10-charlie --file ${POOL}/rhel10-charlie.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-delta   --file ${POOL}/rhel10-delta.qcow2

echo "== Cloning Exam 3 VMs =="
sudo virt-clone --original rhel10-golden --name rhel10-echo    --file ${POOL}/rhel10-echo.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-foxtrot --file ${POOL}/rhel10-foxtrot.qcow2

echo "== Networking =="
sudo virsh attach-interface rhel10-alpha   network rhcsa-net1 --model virtio --config
sudo virsh attach-interface rhel10-bravo   network rhcsa-net1 --model virtio --config
sudo virsh attach-interface rhel10-charlie network rhcsa-net2 --model virtio --config
sudo virsh attach-interface rhel10-delta   network rhcsa-net2 --model virtio --config
sudo virsh attach-interface rhel10-echo    network rhcsa-net3 --model virtio --config
sudo virsh attach-interface rhel10-foxtrot network rhcsa-net3 --model virtio --config

echo "== Hostnames =="
sudo virt-customize -d rhel10-alpha   --hostname rhel10-alpha
sudo virt-customize -d rhel10-bravo   --hostname rhel10-bravo
sudo virt-customize -d rhel10-charlie --hostname rhel10-charlie
sudo virt-customize -d rhel10-delta   --hostname rhel10-delta
sudo virt-customize -d rhel10-echo    --hostname rhel10-echo
sudo virt-customize -d rhel10-foxtrot --hostname rhel10-foxtrot

echo "== Disks =="
sudo "${ADDDISK}" rhel10-alpha   sdb 10
sudo "${ADDDISK}" rhel10-bravo   sdb 10
sudo "${ADDDISK}" rhel10-bravo   sdc 5
sudo "${ADDDISK}" rhel10-charlie sdb 8
sudo "${ADDDISK}" rhel10-charlie sdc 6
sudo "${ADDDISK}" rhel10-charlie sdd 4
sudo "${ADDDISK}" rhel10-delta   sdb 8
sudo "${ADDDISK}" rhel10-echo    vdb 8
sudo "${ADDDISK}" rhel10-echo    vdc 6
sudo "${ADDDISK}" rhel10-foxtrot vdb 8

echo "== Attaching DVD ISO for Task 13/17 repo work (alpha + charlie + echo) =="
for vm in rhel10-alpha rhel10-charlie; do
  sudo virsh attach-disk "${vm}" \
    /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso \
    sda --type cdrom --mode readonly --config
done
sudo virsh change-media rhel10-echo sda \
  /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso --insert --config

echo "== Seeding Exam 1/2 pre-conditions (offline, no boot needed) =="
sudo virt-customize -d rhel10-bravo   --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-charlie --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-delta   --run-command 'systemctl set-default rescue.target'

echo "== Starting Exam 1/2 VMs =="
for vm in rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta; do
  sudo virsh start "${vm}"
done

echo "== Snapshotting Exam 1/2 exam-ready states =="
sudo virsh snapshot-create-as rhel10-alpha   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-bravo   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-charlie exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-delta   exam2-ready "Exam 2 pristine"

echo "== DONE with automatable steps. =="
echo "== NEXT: manually run Phase 5.5 (foxtrot fstab/root seed, echo labdata/SELinux seed) via 'virsh console', =="
echo "==       then start + snapshot echo/foxtrot as exam3-ready per Phase 5.6. =="
