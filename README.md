---
title: RHCSA Practice Exam - Environment Setup & Usage Guide
tags: [certifications, rhcsa, rhel10, lab, kvm, libvirt, practice, setup]
created: 2026-07-08
covers: [RHCSA Practice Exam 1, RHCSA Practice Exam 2]
note: Golden image build lives here; RHCA lab guide references it downstream.
---

# 🧪 RHCSA Practice Exam — Environment Setup & Usage Guide

> **Purpose:** Build, seed, run, and reset the lab environments for **RHCSA Practice Exam 1** (alpha/bravo) and **RHCSA Practice Exam 2** (charlie/delta).
>
> **Platform:** libvirt/KVM on your existing RHEL host.
>
> **Ordering note:** RHCSA comes first in your cert journey, so the **golden image build lives in this guide**. The later `[[RHCA-Practice-Lab-Node-Setup-Guide]]` reuses the same image and simply references Phase 0 here.
>
> **Key principle:** Each exam has deliberate pre-conditions (broken passwords, extra disks, wrong boot target). Set those up before starting the timer, then snapshot-revert to retake cleanly.

---

## 📊 Exam-at-a-Glance

| Attribute        | Exam 1                               | Exam 2                                      |
| ---------------- | ------------------------------------ | ------------------------------------------- |
| VMs              | `rhel10-alpha`, `rhel10-bravo`       | `rhel10-charlie`, `rhel10-delta`            |
| Subnet           | `192.168.100.0/24`                   | `10.20.30.0/24`                             |
| Node IPs         | alpha `.10`, bravo `.20`             | charlie `.11`, delta `.12`                  |
| Break-in target  | bravo (rd.break method)              | charlie (init=/bin/bash method)             |
| Special boot     | none                                 | delta boots to `rescue.target`             |
| Extra disks      | alpha +10G; bravo +10G, +5G          | charlie +8G, +6G, +4G; delta +8G            |
| Tasks            | 35                                   | 35                                          |
| Time limit       | 2.5 hrs                              | 2.5 hrs                                     |
| Pass mark        | 25 / 35                              | 25 / 35                                     |

---

## 🧱 PHASE 0 — Build the RHEL 10 Golden Image (do this ONCE)

Everything downstream — both RHCSA exams and later the entire RHCA lab — clones from a single `rhel10-golden` image. Build it once, snapshot it, never touch it again.

### 0.1 — Install the virtualization stack on the KVM host

```bash
sudo dnf group install -y "Virtualization Host"
sudo dnf install -y qemu-kvm libvirt virt-install virt-manager \
                    cockpit-machines libguestfs-tools virt-viewer
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

### 0.2 — Create a dedicated storage pool

```bash
sudo mkdir -p /var/lib/libvirt/lab-images
sudo virsh pool-define-as lab dir - - - - "/var/lib/libvirt/lab-images"
sudo virsh pool-build lab
sudo virsh pool-start lab
sudo virsh pool-autostart lab
```

### 0.3 — Write the kickstart file

Place the boot ISO at `/var/lib/libvirt/isos/rhel-10-boot.iso`, then create `/var/lib/libvirt/lab-images/ks/rhel10-golden.ks`:

```text
#version=RHEL10
text
reboot
lang en_US.UTF-8
keyboard us
timezone America/New_York --utc
rootpw --plaintext RootLab_2026
user --name=student --password=student --plaintext --groups=wheel
firewall --enabled --ssh
selinux --enforcing
services --enabled=chronyd,sshd
network --bootproto=dhcp --device=link --activate --hostname=rhel10-golden

ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
autopart --type=lvm

url --url="file:///run/install/repo"
repo --name="AppStream" --baseurl="file:///run/install/repo/AppStream"

%packages
@^Minimal Install
@standard
vim-enhanced
tmux
bind-utils
firewalld
chrony
policycoreutils-python-utils
%end

%post --erroronfail
echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student
chmod 0440 /etc/sudoers.d/student
mkdir -p /home/student/.ssh
chmod 700 /home/student/.ssh
chown student:student /home/student/.ssh
systemctl enable --now cockpit.socket
dnf clean all
%end
```

### 0.4 — Install the golden VM

```bash
sudo virt-install \
  --name rhel10-golden \
  --memory 2048 --vcpus 2 \
  --disk pool=lab,size=20,format=qcow2 \
  --location /var/lib/libvirt/isos/rhel-10-boot.iso \
  --initrd-inject /var/lib/libvirt/lab-images/ks/rhel10-golden.ks \
  --extra-args "inst.ks=file:/rhel10-golden.ks console=ttyS0,115200" \
  --os-variant rhel10.0 \
  --network network=default \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole
```

Watch the install:

```bash
sudo virsh console rhel10-golden
```

### 0.5 — Update and install the guest agent

After first boot, log in and finalize:

```bash
sudo dnf upgrade -y
sudo dnf install -y qemu-guest-agent
sudo shutdown -h now
```

### 0.6 — Sysprep and snapshot

```bash
sudo virt-sysprep -d rhel10-golden \
  --operations defaults,-ssh-userdir,-ssh-hostkeys \
  --hostname localhost.localdomain

sudo virsh snapshot-create-as rhel10-golden clean-baseline \
  "Clean sysprepped RHEL 10 baseline"

sudo virsh snapshot-list rhel10-golden
```

You now have a reusable base. Every exam VM is a clone of this.

---

## 🌐 PHASE 1 — Build the Two Isolated Networks

The two exams use different subnets on purpose (Exam 2 warns about stale ARP and host-key clashes). Define both libvirt networks once.

```bash
cat > /tmp/rhcsa-net1.xml <<'EOF'
<network>
  <name>rhcsa-net1</name>
  <forward mode='nat'/>
  <bridge name='virbr-rhcsa1' stp='on' delay='0'/>
  <domain name='lab.local'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.100' end='192.168.100.199'/>
    </dhcp>
  </ip>
</network>
EOF

cat > /tmp/rhcsa-net2.xml <<'EOF'
<network>
  <name>rhcsa-net2</name>
  <forward mode='nat'/>
  <bridge name='virbr-rhcsa2' stp='on' delay='0'/>
  <domain name='ex200.lab'/>
  <ip address='10.20.30.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.20.30.100' end='10.20.30.199'/>
    </dhcp>
  </ip>
</network>
EOF

for n in 1 2; do
  sudo virsh net-define /tmp/rhcsa-net${n}.xml
  sudo virsh net-autostart rhcsa-net${n}
  sudo virsh net-start rhcsa-net${n}
done

sudo virsh net-list --all
```

> Static IPs are assigned as exam tasks (Task 4 in both). DHCP here is only for initial console access before you complete the networking task.

---

## 🔧 PHASE 2 — Helper Script: Attach Extra Disks

Both exams need multiple raw disks attached unpartitioned. Save as `/usr/local/bin/add-disk.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
VM="${1:?usage: add-disk.sh <vm> <target-dev> <size-GB>}"
DEV="${2:?e.g. sdb}"
SIZE="${3:?e.g. 10}"

IMG="/var/lib/libvirt/lab-images/${VM}-${DEV}.qcow2"
echo "Creating ${SIZE}G disk for ${VM} as ${DEV}"
sudo qemu-img create -f qcow2 "${IMG}" "${SIZE}G"
sudo virsh attach-disk "${VM}" "${IMG}" "${DEV}" \
  --persistent --subdriver qcow2 --targetbus sata
echo "Attached. Inside the VM it appears as /dev/${DEV}."
```

```bash
sudo chmod +x /usr/local/bin/add-disk.sh
```

> Using the SATA bus makes disks appear as `/dev/sdb`, `/dev/sdc`, `/dev/sdd` — matching the exam text exactly. With virtio they would appear as `/dev/vdb` and so on.

---

## 🅰️ PHASE 3 — Exam 1 Setup (alpha & bravo)

### 3.1 — Clone the VMs

```bash
sudo virt-clone --original rhel10-golden --name rhel10-alpha \
  --file /var/lib/libvirt/lab-images/rhel10-alpha.qcow2

sudo virt-clone --original rhel10-golden --name rhel10-bravo \
  --file /var/lib/libvirt/lab-images/rhel10-bravo.qcow2
```

### 3.2 — Attach the Exam 1 network

```bash
for vm in rhel10-alpha rhel10-bravo; do
  sudo virsh detach-interface "${vm}" network --config || true
  sudo virsh attach-interface "${vm}" network rhcsa-net1 \
    --model virtio --config
done
```

### 3.3 — Set hostnames, memory, and CPU

```bash
for vm in rhel10-alpha rhel10-bravo; do
  sudo virsh setmaxmem "${vm}" 2048M --config
  sudo virsh setmem    "${vm}" 2048M --config
  sudo virsh setvcpus  "${vm}" 2 --config --maximum
  sudo virsh setvcpus  "${vm}" 2 --config
done

sudo virt-customize -d rhel10-alpha --hostname rhel10-alpha
sudo virt-customize -d rhel10-bravo --hostname rhel10-bravo
```

### 3.4 — Attach extra disks

```bash
sudo /usr/local/bin/add-disk.sh rhel10-alpha sdb 10
sudo /usr/local/bin/add-disk.sh rhel10-bravo sdb 10
sudo /usr/local/bin/add-disk.sh rhel10-bravo sdc 5
```

> Storage tasks (16–20) target bravo `/dev/sdb` and `/dev/sdc`. Alpha's extra disk is optional. Leave all disks unpartitioned.

### 3.5 — Seed the break-in condition on bravo

Task 1 requires bravo's root password to be unknown. Scramble it and discard the value:

```bash
sudo virt-customize -d rhel10-bravo \
  --root-password "password:$(openssl rand -base64 24)"
echo "bravo root password scrambled — break in via rd.break (Task 1)."
```

Leave alpha's root password at the known golden value (`RootLab_2026`).

### 3.6 — Start and snapshot

```bash
sudo virsh start rhel10-alpha
sudo virsh start rhel10-bravo

for vm in rhel10-alpha rhel10-bravo; do
  sudo virsh snapshot-create-as "${vm}" exam1-ready \
    "Exam 1 pristine start: disks attached, bravo root scrambled"
done
```

---

## 🅱️ PHASE 4 — Exam 2 Setup (charlie & delta)

### 4.1 — Clone the VMs

```bash
sudo virt-clone --original rhel10-golden --name rhel10-charlie \
  --file /var/lib/libvirt/lab-images/rhel10-charlie.qcow2

sudo virt-clone --original rhel10-golden --name rhel10-delta \
  --file /var/lib/libvirt/lab-images/rhel10-delta.qcow2
```

### 4.2 — Attach the Exam 2 network

```bash
for vm in rhel10-charlie rhel10-delta; do
  sudo virsh detach-interface "${vm}" network --config || true
  sudo virsh attach-interface "${vm}" network rhcsa-net2 \
    --model virtio --config
done
```

### 4.3 — Set hostnames, memory, and CPU

```bash
for vm in rhel10-charlie rhel10-delta; do
  sudo virsh setmaxmem "${vm}" 2048M --config
  sudo virsh setmem    "${vm}" 2048M --config
  sudo virsh setvcpus  "${vm}" 2 --config --maximum
  sudo virsh setvcpus  "${vm}" 2 --config
done

sudo virt-customize -d rhel10-charlie --hostname rhel10-charlie
sudo virt-customize -d rhel10-delta   --hostname rhel10-delta
```

### 4.4 — Attach extra disks

```bash
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdb 8
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdc 6
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdd 4
sudo /usr/local/bin/add-disk.sh rhel10-delta   sdb 8
```

### 4.5 — Seed the break-in condition on charlie

```bash
sudo virt-customize -d rhel10-charlie \
  --root-password "password:$(openssl rand -base64 24)"
echo "charlie root password scrambled — break in via init=/bin/bash (Task 1)."
```

### 4.6 — Seed the rescue.target condition on delta

```bash
sudo virt-customize -d rhel10-delta \
  --run-command 'systemctl set-default rescue.target'
echo "delta default target set to rescue.target (Task 2 changes it to graphical)."
```

> `rescue.target` prompts for the root password. Keep delta's root password at the known golden value so you can enter the rescue shell — only charlie's password is scrambled.

### 4.7 — Start and snapshot

```bash
sudo virsh start rhel10-charlie
sudo virsh start rhel10-delta

for vm in rhel10-charlie rhel10-delta; do
  sudo virsh snapshot-create-as "${vm}" exam2-ready \
    "Exam 2 pristine start: charlie root scrambled, delta rescue.target"
done
```

---

## ▶️ RUNNING A PRACTICE EXAM

### Pre-flight

```bash
sudo virsh list --all
sudo virsh snapshot-list rhel10-alpha
```

Access consoles (use serial console until the network task is done):

```bash
sudo virsh console rhel10-alpha
```

Or use the Cockpit Virtual Machines UI in a browser at `https://<kvm-host>:9090`.

### Exam-day rules

1. Start a real 150-minute timer. No pausing.
2. No internet — only `man`, `info`, `/usr/share/doc`.
3. Type every command; no copy-paste from the exam file.
4. Work the correct host — tasks are tagged `(alpha)`, `(bravo)`, `(both)` in Exam 1 and `(charlie)`, `(delta)`, `(both)` in Exam 2.
5. Reboot-test critical tasks as you go — a broken `fstab` can block boot.
6. Budget roughly 4.3 minutes per task; flag anything over 8 minutes and move on.

### Suggested pacing

| Phase                 | Time budget | Tasks       |
| --------------------- | ----------- | ----------- |
| Read-through          | 5 min       | Skim all 35 |
| Boot/recovery + net   | 25 min      | 1–5         |
| Users/perms/SSH       | 25 min      | 6–12        |
| Software management   | 15 min      | 13–15       |
| Storage (heaviest)    | 35 min      | 16–24       |
| Services/logging/time | 20 min      | 25–29       |
| Scripting             | 10 min      | 30–32       |
| SELinux + containers  | 10 min      | 33–35       |
| Reserve / verify      | 5 min       | Final reboot + spot-check |

---

## ✅ GRADING & VERIFICATION

### The reboot test

RHCSA is graded after a reboot. Most tasks are marked reboot-sensitive. Before scoring:

```bash
sudo virsh reboot rhel10-alpha
sudo virsh reboot rhel10-bravo
```

Wait for both to return, then verify each persistence-marked task.

### Self-grading workflow

1. Walk the Grading Checklist table in each exam file.
2. Mark a task done only if it persisted through reboot where applicable.
3. Tally the score. Pass is 25/35.
4. Log the result in your weekly review note.

### Optional automated grader

You have the Ansible skills to auto-verify. Example task patterns:

```yaml
---
- name: RHCSA Exam 1 - Automated Grader
  hosts: all
  gather_facts: true
  tasks:

    - name: "Task 2 - default target is multi-user (bravo)"
      ansible.builtin.command: systemctl get-default
      register: t2
      changed_when: false
      failed_when: false
      when: inventory_hostname == 'bravo'

    - name: "Task 6 - user alice exists with UID 1050 (alpha)"
      ansible.builtin.getent:
        database: passwd
        key: alice
      when: inventory_hostname == 'alpha'

    - name: "Task 17 - /mnt/xfs_data mounted (bravo)"
      ansible.builtin.command: findmnt /mnt/xfs_data
      register: t17
      changed_when: false
      failed_when: false
      when: inventory_hostname == 'bravo'

    - name: "Task 33 - SELinux enforcing (alpha)"
      ansible.builtin.command: getenforce
      register: t33
      changed_when: false
      failed_when: "'Enforcing' not in t33.stdout"
      when: inventory_hostname == 'alpha'
```

---

## 🔄 RESETTING FOR A RETAKE

```bash
# Exam 1 reset
for vm in rhel10-alpha rhel10-bravo; do
  sudo virsh destroy "${vm}" 2>/dev/null || true
  sudo virsh snapshot-revert "${vm}" exam1-ready
  sudo virsh start "${vm}"
done
echo "Exam 1 reset to pristine."
```

```bash
# Exam 2 reset
for vm in rhel10-charlie rhel10-delta; do
  sudo virsh destroy "${vm}" 2>/dev/null || true
  sudo virsh snapshot-revert "${vm}" exam2-ready
  sudo virsh start "${vm}"
done
echo "Exam 2 reset to pristine."
```

> Reverting takes about 2 seconds versus roughly 20 minutes to rebuild. This is the single biggest time-saver in your practice loop.

---

## 🧰 QUICK-REFERENCE: FULL REBUILD IN ONE BLOCK

For rebuilding everything from scratch after a golden-image update:

```bash
#!/usr/bin/env bash
# rebuild-rhcsa-labs.sh — full teardown + rebuild of both exam environments
set -euo pipefail

POOL=/var/lib/libvirt/lab-images

teardown() {
  for vm in "$@"; do
    sudo virsh destroy "${vm}" 2>/dev/null || true
    sudo virsh undefine "${vm}" --remove-all-storage --snapshots-metadata 2>/dev/null || true
  done
}

echo "== Tearing down existing exam VMs =="
teardown rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta

echo "== Cloning Exam 1 VMs =="
sudo virt-clone --original rhel10-golden --name rhel10-alpha --file ${POOL}/rhel10-alpha.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-bravo --file ${POOL}/rhel10-bravo.qcow2

echo "== Cloning Exam 2 VMs =="
sudo virt-clone --original rhel10-golden --name rhel10-charlie --file ${POOL}/rhel10-charlie.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-delta   --file ${POOL}/rhel10-delta.qcow2

echo "== Networking =="
sudo virsh attach-interface rhel10-alpha   network rhcsa-net1 --model virtio --config
sudo virsh attach-interface rhel10-bravo   network rhcsa-net1 --model virtio --config
sudo virsh attach-interface rhel10-charlie network rhcsa-net2 --model virtio --config
sudo virsh attach-interface rhel10-delta   network rhcsa-net2 --model virtio --config

echo "== Hostnames =="
sudo virt-customize -d rhel10-alpha   --hostname rhel10-alpha
sudo virt-customize -d rhel10-bravo   --hostname rhel10-bravo
sudo virt-customize -d rhel10-charlie --hostname rhel10-charlie
sudo virt-customize -d rhel10-delta   --hostname rhel10-delta

echo "== Disks =="
sudo /usr/local/bin/add-disk.sh rhel10-alpha   sdb 10
sudo /usr/local/bin/add-disk.sh rhel10-bravo   sdb 10
sudo /usr/local/bin/add-disk.sh rhel10-bravo   sdc 5
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdb 8
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdc 6
sudo /usr/local/bin/add-disk.sh rhel10-charlie sdd 4
sudo /usr/local/bin/add-disk.sh rhel10-delta   sdb 8

echo "== Seeding exam pre-conditions =="
sudo virt-customize -d rhel10-bravo   --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-charlie --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-delta   --run-command 'systemctl set-default rescue.target'

echo "== Starting VMs =="
for vm in rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta; do
  sudo virsh start "${vm}"
done

echo "== Snapshotting exam-ready states =="
sudo virsh snapshot-create-as rhel10-alpha   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-bravo   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-charlie exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-delta   exam2-ready "Exam 2 pristine"

echo "== DONE. Both exam environments ready. =="
```

---

## 🚨 TROUBLESHOOTING

| Symptom                                        | Cause / Fix                                                            |
| ---------------------------------------------- | ---------------------------------------------------------------------- |
| Disks show as `/dev/vdb` not `/dev/sdb`        | Used virtio bus. Re-attach with SATA bus, or adapt the task text       |
| delta boots to multi-user, not rescue          | `set-default rescue.target` did not apply — re-run the virt-customize step |
| Cannot break into bravo/charlie                | Password was not scrambled — re-run with a fresh `openssl rand`         |
| Both exams' VMs see each other                 | Wrong network — alpha/bravo on `rhcsa-net1`, charlie/delta on `rhcsa-net2` |
| `snapshot-revert` fails: domain running        | Run `virsh destroy <vm>` first, then revert                            |
| Static IP task breaks SSH access               | Expected — use `virsh console` until the network task is done          |
| Reboot test wipes a completed task             | The task was not made persistent — redo it correctly                   |
| GRUB edit will not accept the break-in args    | Press `e` at the boot menu, edit the `linux` line, then `Ctrl+X`       |
| Extra disks missing after revert               | Snapshot was taken before disks attached — re-take the exam-ready snapshot |

---

## 📅 HOW THIS FITS THE CERT TIMELINE

Per `[[RHCA-Ansible-Cert-Path-Timeline]]`:

- RHCSA (EX200) is the prerequisite, targeted mid-September 2026.
- Use Exam 1 first (foundational methods: rd.break, fdisk, simple LVM).
- Use Exam 2 second (advanced variants: init=/bin/bash, parted, striped LVM, ACLs, rich rules).
- Aim to pass both practice exams at 30/35 or better before booking the real EX200.
- The `rhel10-golden` image built in Phase 0 is reused by the RHCA lab — the RHCA guide references it rather than rebuilding.

### Recommended drill cadence (pre-September)

| Week        | Activity                                                 |
| ----------- | -------------------------------------------------------- |
| Aug, week 1 | Full timed run of Exam 1; self-grade; note weak sections |
| Aug, week 2 | Revert; redo only failed tasks; full re-run              |
| Aug, week 3 | Full timed run of Exam 2 (harder variants)               |
| Aug, week 4 | Revert; redo failed tasks; mixed drill of both           |
| Sep, week 1 | Both exams back-to-back at 30/35+; book real EX200       |
| Sep, week 2 | Light review; take real EX200                            |

---

## 🔗 Related Vault Notes

- 📄 `[[RHCSA Practice Exam 1 - RHEL 10]]` — 35 tasks, alpha/bravo
- 📄 `[[RHCSA Practice Exam 2 - RHEL 10]]` — 35 tasks, charlie/delta
- 📄 `[[RHCA-Practice-Lab-Node-Setup-Guide]]` — reuses the golden image from Phase 0 here
- 📄 `[[RHCA-Ansible-Cert-Path-Timeline]]` — where RHCSA fits in the RHCA journey

---

*Setup and usage guide created 2026-07-08. Golden image build lives here; RHCA lab work builds on it. Covers RHCSA Practice Exam 1 (alpha/bravo) and Exam 2 (charlie/delta) on RHEL 10.*
