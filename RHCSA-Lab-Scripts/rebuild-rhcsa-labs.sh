#!/usr/bin/env bash
# rebuild-rhcsa-labs.sh — full teardown + rebuild of all three exam environments
# Run as your normal user (it calls sudo itself) so SSH_PUBKEY resolves to YOUR key.
set -euo pipefail

POOL=/home/libvirt/images
DVD_ISO=/home/libvirt/iso/rhel-10.2-x86_64-dvd.iso    # README Phase 2.5
SCRIPTS="$(dirname "$(readlink -f "$0")")"              # sibling scripts, wherever the repo is cloned
ADDDISK="${SCRIPTS}/add-disk.sh"
SSH_PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"   # injected for 'student' on every exam VM
SSH_KEY="${SSH_PUBKEY%.pub}"
SSH_OPTS=(-i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=5
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
ALL_VMS=(rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta rhel10-echo rhel10-foxtrot)

[[ -f ${DVD_ISO} ]] || {
  echo "DVD ISO not found: ${DVD_ISO}. Download it first (README Phase 2.5, rhel10-dvd-download.sh)." >&2
  exit 1
}

[[ -r ${SSH_PUBKEY} && -r ${SSH_KEY} ]] || {
  echo "SSH key pair not found: ${SSH_KEY}{,.pub}. Create one (ssh-keygen -t ed25519) or set SSH_PUBKEY." >&2
  exit 1
}

# Golden must carry an NM keyfile profile that is not pinned to golden's MAC, or every
# clone boots with no network (virt-sysprep's net-nmconn op deletes them; see README 0.7).
check_golden_network() {
  local dir=/etc/NetworkManager/system-connections f ok=0
  for f in $(sudo virt-ls -d rhel10-golden "${dir}" 2>/dev/null | grep '\.nmconnection$'); do
    if sudo virt-cat -d rhel10-golden "${dir}/${f}" | grep -q '^mac-address='; then
      echo "golden: ${f} is pinned to a MAC address; clones will not match it" >&2
    else
      echo "golden: network profile ${f} OK"
      ok=1
    fi
  done
  (( ok )) || {
    echo "golden has no usable NM profile in ${dir}. Re-add one (README 0.7) and re-sysprep with -net-nmconn before rebuilding." >&2
    exit 1
  }
}

teardown() {
  for vm in "$@"; do
    sudo virsh destroy "${vm}" 2>/dev/null || true
    sudo virsh undefine "${vm}" --remove-all-storage --snapshots-metadata 2>/dev/null || true
  done
}

# Wait for a DHCP lease and a working SSH login as student; prints the IP
wait_for_ssh() {
  local vm=$1 ip=""
  for _ in $(seq 60); do
    ip=$(sudo virsh domifaddr "${vm}" 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
    if [[ -n ${ip} ]] && ssh "${SSH_OPTS[@]}" student@"${ip}" true 2>/dev/null; then
      echo "${ip}"
      return 0
    fi
    sleep 5
  done
  echo "${vm}: no SSH after 5 minutes (try: sudo virsh console ${vm})" >&2
  return 1
}

wait_for_shutoff() {
  local vm=$1
  for _ in $(seq 60); do
    [[ $(sudo virsh domstate "${vm}") == "shut off" ]] && return 0
    sleep 2
  done
  echo "${vm}: still running after 2 minutes" >&2
  return 1
}

echo "== Checking golden network profile =="
[[ $(sudo virsh domstate rhel10-golden) == "shut off" ]] || {
  echo "rhel10-golden is running; shut it down before rebuilding" >&2
  exit 1
}
check_golden_network

echo "== Tearing down existing exam VMs =="
teardown "${ALL_VMS[@]}"

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
# Move golden's single NIC (enp1s0) from 'default' onto the exam network. --edit keeps its
# MAC and PCI slot, so the guest still sees enp1s0 and its DHCP profile still applies.
declare -A NET_OF=([rhel10-alpha]=rhcsa-net1 [rhel10-bravo]=rhcsa-net1 [rhel10-charlie]=rhcsa-net2
                   [rhel10-delta]=rhcsa-net2 [rhel10-echo]=rhcsa-net3 [rhel10-foxtrot]=rhcsa-net3)
for vm in "${ALL_VMS[@]}"; do
  sudo virt-xml "${vm}" --edit --network network="${NET_OF[${vm}]}"
done

echo "== Hostnames, serial console, student SSH key, grader script =="
# Grader is copied offline: delta (rescue.target) and foxtrot (broken fstab) have no sshd yet
declare -A EXAM_OF=([rhel10-alpha]=1 [rhel10-bravo]=1 [rhel10-charlie]=2
                    [rhel10-delta]=2 [rhel10-echo]=3 [rhel10-foxtrot]=3)
for vm in "${ALL_VMS[@]}"; do
  grader="ex${EXAM_OF[${vm}]}-verify.sh"
  sudo virt-customize -d "${vm}" --hostname "${vm}" \
    --run "${SCRIPTS}/vm-serial-console.sh" \
    --ssh-inject "student:file:${SSH_PUBKEY}" \
    --upload "${SCRIPTS}/${grader}:/home/student/${grader}" \
    --run-command "chown student:student /home/student/${grader} && chmod 755 /home/student/${grader}"
done

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

echo "== Attaching DVD ISO to every exam VM (local repo source for all nodes) =="
# sda is the golden image's built-in CD-ROM drive, so insert media rather than attach a new disk
for vm in "${ALL_VMS[@]}"; do
  sudo virsh change-media "${vm}" sda \
    "${DVD_ISO}" --insert --config
done

echo "== Seeding Exam 1/2 pre-conditions (offline, no boot needed) =="
# alpha T24: faults to diagnose. /srv/webcontent is owned by no package, so no rpm install resets it
sudo virt-customize -d rhel10-alpha \
  --run-command 'mkdir -p /srv/webcontent && chown nobody:nobody /srv/webcontent && chmod 777 /srv/webcontent' \
  --run-command 'install -m 777 /dev/null /tmp/badperms'
sudo virt-customize -d rhel10-bravo   --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-charlie --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-delta   --run-command 'systemctl set-default rescue.target'

echo "== Seeding Exam 3 foxtrot (offline): bogus fstab entry + scrambled root =="
sudo virt-customize -d rhel10-foxtrot \
  --append-line '/etc/fstab:UUID=deadbeef-0000-0000-0000-000000000000 /mnt/archive xfs defaults 0 0' \
  --root-password "password:$(openssl rand -base64 24)"

echo "== Seeding Exam 3 echo (over SSH): labdata.service + SELinux violations =="
sudo virsh start rhel10-echo
ECHO_IP=$(wait_for_ssh rhel10-echo)
ssh "${SSH_OPTS[@]}" student@"${ECHO_IP}" 'sudo bash -s' < "${SCRIPTS}/ex3-seed-echo.sh"
ssh "${SSH_OPTS[@]}" student@"${ECHO_IP}" 'sudo systemctl poweroff' || true
wait_for_shutoff rhel10-echo

echo "== Confirming all exam VMs are shut off =="
for vm in "${ALL_VMS[@]}"; do
  wait_for_shutoff "${vm}"
done

echo "== Snapshotting exam-ready states (VMs shut off; a revert also leaves them off) =="
sudo virsh snapshot-create-as rhel10-alpha   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-bravo   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-charlie exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-delta   exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-echo    exam3-ready \
  "Exam 3 pristine: echo labdata + SELinux seeded"
sudo virsh snapshot-create-as rhel10-foxtrot exam3-ready \
  "Exam 3 pristine: foxtrot fstab broken + root scrambled"

echo "== DONE. All six VMs are built, seeded, snapshotted and shut off. =="
echo "==   Start:   sudo virsh start <vm> =="
echo "==   Console: sudo virsh console <vm>   (GRUB menu, boot messages and login on serial) =="
echo "==   SSH:     ssh student@<ip>           (key-based; find the IP with: sudo virsh domifaddr <vm>) =="
