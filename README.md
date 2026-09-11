---
title: RHCSA Practice Exam - Environment Setup & Usage Guide
tags: [certifications, rhcsa, rhel10, lab, kvm, libvirt, practice, setup]
created: 2026-07-08
covers: [RHCSA Practice Exam 1, RHCSA Practice Exam 2, RHCSA Practice Exam 3]
note: Golden image build lives here; RHCA lab guide references it downstream.
---
# 🧪 RHCSA Practice Exam — Environment Setup & Usage Guide

> **Purpose:** Build, seed, run, and reset the lab environments for **RHCSA Practice Exam 1** (alpha/bravo), **RHCSA Practice Exam 2** (charlie/delta), and **RHCSA Practice Exam 3** (echo/foxtrot).
> **Platform:** libvirt/KVM on your existing RHEL host.
> **Ordering note:** RHCSA comes first in your cert journey, so the **golden image build lives in this guide**. The later `[[RHCA-Practice-Lab-Node-Setup-Guide]]` reuses the same image and simply references Phase 0 here.
> **Key principle:** Each exam has deliberate pre-conditions (broken passwords, extra disks, wrong boot target). Set those up before starting the timer, then snapshot-revert to retake cleanly.

---

## 📊 Exam-at-a-Glance

| Attribute         | Exam 1                                       | Exam 2                                         | Exam 3                                          |
| ----------------- | -------------------------------------------- | ---------------------------------------------- | ----------------------------------------------- |
| VMs               | `rhel10-alpha`, `rhel10-bravo`           | `rhel10-charlie`, `rhel10-delta`           | `rhel10-echo`, `rhel10-foxtrot`             |
| Subnet            | `192.168.100.0/24`                         | `10.20.30.0/24`                              | `172.16.40.0/24`                              |
| Node IPs          | alpha`.10`, bravo `.20`                  | charlie`.11`, delta `.12`                  | echo`.21`, foxtrot `.22`                    |
| Break-in target   | bravo (init=/bin/bash method)                | charlie (init=/bin/bash method)                | foxtrot (break-in **to repair a broken fstab**) |
| Special boot      | none                                         | delta boots to`rescue.target`                | foxtrot **will not boot** (seeded bad fstab)    |
| Extra disks       | alpha +10G; bravo +10G, +5G                  | charlie +8G, +6G, +4G; delta +8G               | echo +8G, +6G; foxtrot +8G                      |
| Local repo source | DVD ISO attached to`alpha` as `/dev/sr0` | DVD ISO attached to`charlie` as `/dev/sr0` | DVD ISO attached to`echo` as `/dev/sr0`     |
| Tasks             | 35                                           | 35                                             | 35 (26 cover untested objectives)               |
| Answer key        | Separate section at end of file              | Separate section at end of file                | Separate section at end of file                 |
| Time budget       | 3 hrs (see note)                             | 3 hrs (see note)                               | 4 hrs, or split (see note)                      |
| Pass mark         | 25 / 35                                      | 25 / 35                                        | 25 / 35                                         |

> **⏱️ On time budgets:** these papers are 35 tasks each — far more than the real EX200 presents. The original 2.5 hrs works out to ~4.3 min/task and is not achievable; Exam 3 in particular has tasks with six or seven sub-parts (T7, T9, T10, T27). Treat the budgets above as realistic, and **do not read a timer overrun as "not ready"** — that would be a false signal. For Exam 3, two timed sittings (Sections 1–6, then 7–11) is the better drill.
>
> Confirm the **real** EX200 duration on Red Hat's current objectives page before booking. It presents fewer, larger tasks than these papers do, so per-task pacing here does not transfer directly.

> **Exam 3 build note:** `rhcsa-net3` is defined in Phase 1 alongside the other two networks, and the full-rebuild script plus the retake-reset block below both cover `echo`/`foxtrot`. The step-by-step clone/seed walkthrough for Exam 3 lives in `[[RHCSA Practice Exam 3 - RHEL 10]]` itself, since its three deliberately broken pre-conditions are specific to that exam.

---

## 🧱 PHASE 0 — Build the RHEL 10 Golden Image (do this ONCE)

Everything downstream — both RHCSA exams and later the entire RHCA lab — clones from a single `rhel10-golden` image. Build it once, snapshot it, never touch it again.

> **Storage note:** The default libvirt pool under `/var/lib/libvirt/images` is on the root filesystem and too small for a multi-VM lab. We use the dedicated pool created on `/home` (which has the free space):
>
> - **Disk images pool:** `/home/libvirt/images` (libvirt pool name: `home-lab`)
> - **ISO storage:** `/home/libvirt/iso`

### 0.1 — Install the virtualization stack on the KVM host

```bash
sudo dnf group install -y "Virtualization Host"
sudo dnf install -y qemu-kvm libvirt virt-install virt-manager \
                    cockpit-machines libguestfs-tools virt-viewer \
                    guestfs-tools
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

### 0.2 — Verify (or create) the storage pools on /home

The image pool was created yesterday. Confirm it's present and active:

```bash
sudo virsh pool-list --all
sudo virsh pool-info homepool
```

If for any reason it needs to be (re)defined, here are the exact steps for both the image pool and an ISO pool:

```bash
# Image pool (skip if 'homepool' already exists and is active)
sudo mkdir -p /home/libvirt/images
sudo virsh pool-define-as homepool dir - - - - "/home/libvirt/images"
sudo virsh pool-build homepool
sudo virsh pool-start homepool
sudo virsh pool-autostart homepool

# ISO pool for install media
sudo mkdir -p /home/libvirt/iso
sudo virsh pool-define-as isopool dir - - - - "/home/libvirt/iso"
sudo virsh pool-build isopool
sudo virsh pool-start isopool
sudo virsh pool-autostart isopool
```

> **SELinux note (important on /home):** libvirt's default image label context is expected under `/var/lib/libvirt/images`. When storing images under `/home`, make sure the qemu processes can access them. Either confirm the pool set the right contexts, or apply them explicitly:
>
> ```bash
> # Persistent SELinux fcontext for the custom pool paths
> sudo semanage fcontext -a -t virt_image_t '/home/libvirt/images(/.*)?'
> sudo semanage fcontext -a -t virt_content_t '/home/libvirt/iso(/.*)?'
> sudo restorecon -Rv /home/libvirt
> ```
>
> If you use `virt-install`/`virsh` with `security_driver = "selinux"` and hit permission denials, also verify `/home` itself is traversable by qemu (mode `0711` on the parent dirs) and that `dynamic_ownership` in `/etc/libvirt/qemu.conf` is behaving as expected.

### 0.3 / 0.4 — Install the Golden VM (choose ONE path)

> **Why two paths:** The **Boot ISO** contains only the installer — no package trees. A fully headless kickstart with `%packages` therefore **cannot** install from the Boot ISO alone; it needs either a network repo or the full media. The **DVD ISO** carries `BaseOS`/`AppStream`, so `file:///run/install/repo` resolves and the install runs unattended.
>
> | Path        | Media            | Interaction                   | Package source                          | Best when                                                          |
> | ----------- | ---------------- | ----------------------------- | --------------------------------------- | ------------------------------------------------------------------ |
> | **A** | Boot ISO (~1 GB) | Manual, via graphical console | Red Hat CDN (registered) or network URL | You want a small download and don't mind clicking through Anaconda |
> | **B** | DVD ISO (~8 GB)  | Zero-touch kickstart          | DVD (`file:///run/install/repo`)      | You want a repeatable, hands-off build                             |

---

#### 🅰️ PATH A — Manual GUI Install from the Boot ISO

Uses the graphical Anaconda installer driven through the **Cockpit VM console (VNC)** — no local GUI needed, just a browser.

**A.1 — Stage the Boot ISO**

```bash
# Boot ISO in the ISO pool
ls -lh /home/libvirt/iso/rhel-10.1-x86_64-boot.iso
sudo virsh pool-refresh isopool
```

**A.2 — Launch the installer with a graphical console**

```bash
sudo virt-install \
  --name rhel10-golden \
  --memory 2048 --vcpus 2 \
  --disk pool=homepool,size=20,format=qcow2 \
  --location /home/libvirt/iso/rhel-10.1-x86_64-boot.iso \
  --os-variant rhel10.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole
```

> `--graphics vnc` (instead of `--graphics none`) is the key change — it exposes a graphical console you can open from **Cockpit → Virtual Machines → rhel10-golden → Console**, or with `virt-viewer --connect qemu+ssh://<host>/system rhel10-golden`.

**A.3 — Work through Anaconda manually**

Set these to match what the kickstart would have done:

- **Installation Source:** the Boot ISO has no packages, so either:
  - **Connect to Red Hat** (Installation Source → *Red Hat CDN*) using your Developer subscription — pulls BaseOS/AppStream over the network, **or**
  - Set a **network install source URL** (e.g. a mirror/satellite) if you have one.
- **Software Selection:** *Minimal Install* + *Standard* (add `vim-enhanced`, `tmux`, `bind-utils`, `chrony`, `policycoreutils-python-utils` after first boot if not offered).
- **Installation Destination:** auto/LVM on the single 20 GB disk.
- **Network & Hostname:** `rhel10-golden`, DHCP.
- **root password:** `RootLab_2026`; **create user** `student` (add to `wheel`).
- **Time & Date:** `America/New_York`, enable NTP (chrony).

**A.4 — Post-install parity with the kickstart**

Once it reboots, log in as `student` and reproduce the kickstart's `%post`:

```bash
echo 'student ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/student
sudo chmod 0440 /etc/sudoers.d/student
sudo systemctl enable --now cockpit.socket
sudo dnf clean all
```

Then continue to **0.5** (update + guest agent).

---

#### 🅱️ PATH B — Headless Kickstart Install from the DVD ISO

Fully automated, no console interaction. Requires the **DVD ISO** — download it first via **Phase 2.5** (the Boot ISO will *not* work here).

> **Ordering note:** Path B depends on the DVD ISO, so run **Phase 2.5** *before* Phase 0 if you choose this path. (Phase 2.5 is otherwise positioned for the Task 13 repo work, but the same file serves both purposes — one download, two uses.)

**B.1 — Stage the DVD ISO and write the kickstart**

```bash
ls -lh /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso   # from Phase 2.5
sudo mkdir -p /home/libvirt/images/ks
sudo vim /home/libvirt/images/ks/rhel10-golden.ks
```

Kickstart contents (unchanged logic — the `file:///run/install/repo` lines now resolve because the **DVD** is the install source):

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

# Resolves against the mounted DVD (has BaseOS + AppStream); NOT valid with the Boot ISO
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

**B.2 — Install the golden VM (headless, DVD as source)**

```bash
sudo virt-install \
  --name rhel10-golden \
  --memory 2048 --vcpus 2 \
  --disk pool=homepool,size=20,format=qcow2 \
  --location /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso \
  --initrd-inject /home/libvirt/images/ks/rhel10-golden.ks \
  --extra-args "inst.ks=file:/rhel10-golden.ks console=ttyS0,115200" \
  --os-variant rhel10.0 \
  --network network=default \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole
```

> The `--location` pointing at the **DVD** ISO instead of the Boot ISO. That's what makes `file:///run/install/repo` (and the whole `%packages` block) actually work unattended.

**B.3 — Watch the install**

```bash
sudo virsh console rhel10-golden
```

It reboots itself on completion (`reboot` directive).

```

### 0.5 — Update and install the guest agent

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

 \You now have a reusable base. Every exam VM is a clone of this.

---

## 🌐 PHASE 1 — Build the Two Isolated Networks

The three exams use different subnets on purpose (Exam 2 warns about stale ARP and host-key clashes). Define all three libvirt networks once.

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

cat > /tmp/rhcsa-net3.xml <<'EOF'
<network>
  <name>rhcsa-net3</name>
  <forward mode='nat'/>
  <bridge name='virbr-rhcsa3' stp='on' delay='0'/>
  <domain name='ex200.net'/>
  <ip address='172.16.40.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='172.16.40.100' end='172.16.40.199'/>
    </dhcp>
  </ip>
</network>
EOF

for n in 1 2 3; do
  sudo virsh net-define /tmp/rhcsa-net${n}.xml
  sudo virsh net-autostart rhcsa-net${n}
  sudo virsh net-start rhcsa-net${n}
done

sudo virsh net-list --all
```

> Static IPs are assigned as exam tasks (Task 4 in both). DHCP here is only for initial console access before you complete the networking task.

---

## 🔧 PHASE 2 — Helper Script: Attach Extra Disks

All three exams need multiple raw disks attached unpartitioned. Save as `~/my_work_tools/bin/bash/add-disk.sh` (that is the path every phase below invokes):

> **Always pass a `vdX` target.** The script attaches on the **virtio** bus, so the guest names the disk `/dev/vdb`, `/dev/vdc`, … Passing `sdb` here would be misleading — the guest still sees `vdb`, and every exam's task text says `/dev/vdX`.

```bash
#!/usr/bin/env bash
set -euo pipefail
VM="${1:?usage: add-disk.sh <vm> <target-dev> <size-GB>}"
DEV="${2:?e.g. vdb}"
SIZE="${3:?e.g. 10}"

IMG="/home/libvirt/images/${VM}-${DEV}.qcow2"
echo "Creating ${SIZE}G disk for ${VM} as ${DEV}"
sudo qemu-img create -f qcow2 "${IMG}" "${SIZE}G"
sudo virsh attach-disk "${VM}" "${IMG}" "${DEV}" \
  --persistent --subdriver qcow2 --targetbus virtio
echo "Attached. Inside the VM it appears as /dev/${DEV}."
```

```bash
sudo chmod +x ~/my_work_tools/bin/bash/add-disk.sh
```

---

## 💿 PHASE 2.5 — Stage the RHEL 10 DVD ISO (Repository Tasks / Task 13)

> **Why:** Task 13 in *both* exams builds a **local YUM/DNF repo from the RHEL 10 installation ISO**. The lightweight **Boot ISO** used to build the golden image in Phase 0 does **not** contain the `BaseOS`/`AppStream` package trees — only the full **DVD ISO** does. This phase downloads the DVD ISO once (headless, CLI-only) and attaches it to the relevant exam VM as a virtual CD-ROM (`/dev/sr0`), matching how the real EX200 presents install media.
> **One-time cost:** ~8 GB download. Do it once; it lives in the ISO pool and is reused on every retake.
> **Note:** If building the golden image via Path B (headless kickstart), run this phase first; the DVD ISO it downloads is reused by both Phase 0.4-B and Task 13."

### 2.5.1 — Prep the ISO pool for non-root download

The ISO pool (`/home/libvirt/iso`) is owned by `root`. To download into it as your regular user **without** changing ownership (which would break libvirt/qemu access), grant yourself access with an **additive ACL** — it layers on top of the existing owner/group/mode, breaking nothing:

```bash
# Additive: does NOT change owner, group, or existing mode bits
sudo setfacl -m u:"$USER":rwx /home/libvirt/iso
sudo setfacl -d -m u:"$USER":rwX /home/libvirt/iso   # capital X: dirs get +x, files don't
getfacl /home/libvirt/iso                            # confirm: user:<you>:rwx present
```

> SELinux context for this path (`virt_content_t`) is already handled by the Phase 0.2 pool setup. If you skipped it, re-run the `semanage fcontext … virt_content_t` + `restorecon` lines from Phase 0.2.

### 2.5.2 — Generate a Red Hat offline API token (one-time, from any browser)

Headless download uses the Red Hat API, so grab a token from a browser on your **laptop** (not the KVM host):

1. Visit **https://access.redhat.com/management/api** → **Generate Token**.
2. Copy the long `eyJ…` string; store it in your password manager.

> The token never expires as long as it's used at least once every 30 days. Treat it like a password — never commit it in plaintext to this shared note.

### 2.5.3 — Download the DVD ISO via CLI (on the KVM host)

```bash
sudo dnf install -y jq curl

# --- fill in ---
offline_token="PASTE_OFFLINE_TOKEN"
# DVD iso SHA-256 from https://developers.redhat.com/products/rhel/download (10.2 release row)
checksum="PASTE_RHEL_10.2_DVD_SHA256"
dest="/home/libvirt/iso"
# ---------------

cd "$dest" || exit 1

# 1) offline token -> short-lived access token
access_token=$(curl -s \
  https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -d grant_type=refresh_token -d client_id=rhsm-api \
  -d refresh_token="$offline_token" | jq -r '.access_token')

# 2) resolve signed URL + filename by checksum
image=$(curl -s -H "Authorization: Bearer $access_token" \
  "https://api.access.redhat.com/management/v1/images/$checksum/download")
filename=$(echo "$image" | jq -r '.body.filename')
url=$(echo "$image" | jq -r '.body.href')

# 3) download (resumable if interrupted)
curl --output "$filename" "$url" --continue-at -
```

### 2.5.4 — Verify integrity and register with the pool

```bash
sha256sum rhel-10.2-x86_64-dvd.iso     # compare against the download-page checksum
sudo virsh pool-refresh isopool         # make libvirt aware of the new volume
sudo virsh vol-list isopool
```

> **Do not** rename the file to a Boot-ISO path — keep DVD and Boot ISOs as distinct files so Phase 0 (Boot) and Phase 2.5 (DVD) never collide.

---

## 🅰️ PHASE 3 — Exam 1 Setup (alpha & bravo)

### 3.1 — Clone the VMs

```bash
sudo virt-clone --original rhel10-golden --name rhel10-alpha \
  --file /home/libvirt/images/rhel10-alpha.qcow2

sudo virt-clone --original rhel10-golden --name rhel10-bravo \
  --file /home/libvirt/images/rhel10-bravo.qcow2
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
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-alpha vdb 10
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-bravo vdb 10
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-bravo vdc 5
```

> Storage tasks (16–20) target bravo `/dev/vdb` and `/dev/vdc`. Alpha's extra disk is optional. Leave all disks unpartitioned.

### 3.5 — Seed the break-in condition on bravo

Task 1 requires bravo's root password to be unknown. Scramble it and discard the value:

```bash
sudo virt-customize -d rhel10-bravo \
  --root-password "password:$(openssl rand -base64 24)"
echo "bravo root password scrambled — break in via rd.break (Task 1)."
```

Leave alpha's root password at the known golden value (`RootLab_2026`).

### 3.5b — Attach the DVD ISO to alpha (Task 13 repo source)

> **Note:** the sda disk is created by deffault as the VMs CD-ROM drive and cannot be removed.  Modify it to insert the .iso as source repo.  If VM is off, remove the `--live` parameter.

```bash
sudo virsh change-media rhel10-alpha sda /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso --insert --config --live
sudo virsh domblklist rhel10-alpha   # confirm the cdrom shows up
```

> Inside alpha it appears as `/dev/sr0`. Students mount it at `/mnt/rhel10iso` and point the `.repo` file at `BaseOS`/`AppStream` (Task 13). Attach **before** the 3.6 snapshot so `exam1-ready` retains the media across reverts.

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
  --file /home/libvirt/images/rhel10-charlie.qcow2

sudo virt-clone --original rhel10-golden --name rhel10-delta \
  --file /home/libvirt/images/rhel10-delta.qcow2
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
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-charlie vdb 8
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-charlie vdc 6
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-charlie vdd 4
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-delta   vdb 8
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

### 4.6b — Attach the DVD ISO to charlie (Task 13 repo source)

> **Note:** the sda disk is created by deffault as the VMs CD-ROM drive and cannot be removed.  Modify it to insert the .iso as source repo.  If VM is off, remove the `--live` parameter.

```bash
sudo virsh change-media rhel10-charlie \
  sda /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso \
  --insert --config --live
sudo virsh domblklist rhel10-charlie
```

> Appears as `/dev/sr0` inside charlie. Attach **before** the 4.7 snapshot so `exam2-ready` keeps the media.

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

1. Start a real timer — **180 minutes** for Exams 1 and 2, **240 minutes** for Exam 3 (or split it into two sittings). No pausing.
2. No internet — only `man`, `info`, `/usr/share/doc`.
3. Type every command; no copy-paste from the exam file.
4. **Do not scroll past the Grading Checklist.** All three exams now keep their answer key in a single section at the end — that is the whole point of the format.
5. Work the correct host — tasks are tagged `(alpha)`/`(bravo)` in Exam 1, `(charlie)`/`(delta)` in Exam 2, `(echo)`/`(foxtrot)` in Exam 3.
6. Reboot-test critical tasks as you go — a broken `fstab` can block boot.
7. Flag anything over 10 minutes and move on. Coming back to a flagged task beats grinding.

### Suggested pacing — Exams 1 & 2 (180 min)

| Phase                 | Time budget | Tasks                     |
| --------------------- | ----------- | ------------------------- |
| Read-through          | 5 min       | Skim all 35               |
| Boot/recovery + net   | 30 min      | 1–5                      |
| Users/perms/SSH       | 30 min      | 6–12                     |
| Software management   | 20 min      | 13–15                    |
| Storage (heaviest)    | 40 min      | 16–24                    |
| Services/logging/time | 25 min      | 25–29                    |
| Scripting             | 15 min      | 30–32                    |
| SELinux + containers  | 30 min      | 33–35                    |
| Reserve / verify      | 5 min       | Final reboot + spot-check |

### Suggested pacing — Exam 3 (240 min, or two sittings)

Exam 3 is heavier per task: Sections 2 and 8 are multi-part answer-capture tasks, and Tasks 1, 4 and 33 are open-ended diagnosis with no hint of the cause.

| Phase                        | Time budget | Tasks  | Sitting |
| ---------------------------- | ----------- | ------ | ------- |
| Read-through                 | 5 min       | All 35 | 1       |
| Boot failure + service diag  | 40 min      | 1–5    | 1       |
| Essential tools              | 45 min      | 6–10   | 1       |
| Users/perms/SELinux contexts | 30 min      | 11–14  | 1       |
| Networking                   | 20 min      | 15–16  | 1       |
| Software management          | 25 min      | 17–19  | 2       |
| Storage                      | 40 min      | 20–24  | 2       |
| NFS + AutoFS                 | 15 min      | 25–26  | 2       |
| Services/logging/scheduling  | 25 min      | 27–30  | 2       |
| Scripting                    | 20 min      | 31–32  | 2       |
| SELinux diagnosis            | 25 min      | 33–34  | 2       |
| Containers                   | 15 min      | 35     | 2       |
| Reserve / verify             | 10 min      | Reboot + run the verify script | 2 |

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

1. **Reboot both hosts first.** Nothing is scored before a reboot.
2. Run the exam's **Quick Verification Script** on each host — all three exams now carry one, in a section just after their Grading Checklist:
   - `ex1-verify.sh` — alpha / bravo
   - `ex2-verify.sh` — charlie / delta
   - `ex3-verify.sh` — echo / foxtrot
3. Walk the Grading Checklist for the tasks the script can't judge (SSH key auth, file transfers, script behaviour, documentation answers).
4. Mark a task done only if it persisted through reboot where applicable.
5. Tally the score. Pass is 25/35.
6. Log the result in your weekly review note.

> **Why the scripts matter more than the checklist:** self-grading from a checklist is the weak link in this whole practice loop — it is easy to tick "done" on something that looked right at the time but didn't actually persist. The scripts check the objectively-verifiable, persistence-sensitive items and will catch exactly that class of mistake. They are a safety net, not a full grader.

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

```bash
# Exam 3 reset
for vm in rhel10-echo rhel10-foxtrot; do
  sudo virsh destroy "${vm}" 2>/dev/null || true
  sudo virsh snapshot-revert "${vm}" exam3-ready
  sudo virsh start "${vm}"
done
echo "Exam 3 reset to pristine (foxtrot will NOT boot — that is Task 1)."
```

> **Exam 3 reverts matter more than the others.** Its pre-conditions are three deliberately broken states (bad fstab, failing unit, two unlabeled SELinux objects). Once you have fixed them, the exam cannot be retaken without a revert — there is no way to "undo" the repairs by hand and be sure you got back to the seeded state.

> Reverting takes about 2 seconds versus roughly 20 minutes to rebuild. This is the single biggest time-saver in your practice loop.

---

## 🧰 QUICK-REFERENCE: FULL REBUILD IN ONE BLOCK

For rebuilding everything from scratch after a golden-image update:

```bash
#!/usr/bin/env bash
# rebuild-rhcsa-labs.sh — full teardown + rebuild of ALL THREE exam environments
set -euo pipefail

POOL=/home/libvirt/images
ADDDISK=~/my_work_tools/bin/bash/add-disk.sh

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

echo "== Disks (virtio bus -> guest sees /dev/vdX) =="
sudo "$ADDDISK" rhel10-alpha   vdb 10
sudo "$ADDDISK" rhel10-bravo   vdb 10
sudo "$ADDDISK" rhel10-bravo   vdc 5
sudo "$ADDDISK" rhel10-charlie vdb 8
sudo "$ADDDISK" rhel10-charlie vdc 6
sudo "$ADDDISK" rhel10-charlie vdd 4
sudo "$ADDDISK" rhel10-delta   vdb 8
sudo "$ADDDISK" rhel10-echo    vdb 8
sudo "$ADDDISK" rhel10-echo    vdc 6
sudo "$ADDDISK" rhel10-foxtrot vdb 8

echo "== Attaching DVD ISO for the repo tasks (alpha + charlie + echo) =="
# 'sda' here is the CD-ROM device, not a data disk — it stays sdX.
for vm in rhel10-alpha rhel10-charlie rhel10-echo; do
  sudo virsh attach-disk "${vm}" \
    /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso \
    sda --type cdrom --mode readonly --config
done

echo "== Seeding Exam 1 + 2 pre-conditions =="
sudo virt-customize -d rhel10-bravo   --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-charlie --root-password "password:$(openssl rand -base64 24)"
sudo virt-customize -d rhel10-delta   --run-command 'systemctl set-default rescue.target'

echo "== Seeding Exam 3 pre-conditions (offline, via virt-customize) =="
# foxtrot: unbootable fstab + unknown root password (Task 1)
sudo virt-customize -d rhel10-foxtrot \
  --root-password "password:$(openssl rand -base64 24)" \
  --append-line '/etc/fstab:UUID=deadbeef-0000-0000-0000-000000000000 /mnt/archive xfs defaults 0 0'

# echo: a unit that fails on boot (Task 4)
sudo virt-customize -d rhel10-echo \
  --write '/etc/systemd/system/labdata.service:[Unit]
Description=Lab Data Collector
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/labdata-collect --daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target' \
  --run-command 'systemctl enable labdata.service'

# echo: httpd seeded into TWO SELinux violations (Task 33)
sudo virt-customize -d rhel10-echo \
  --run-command 'dnf install -y httpd policycoreutils-python-utils setroubleshoot-server || true' \
  --mkdir /srv/intranet \
  --write '/srv/intranet/index.html:Echo Intranet OK' \
  --write '/etc/httpd/conf.d/intranet.conf:Listen 8404
<VirtualHost *:8404>
    DocumentRoot /srv/intranet
    <Directory /srv/intranet>
        Require all granted
    </Directory>
</VirtualHost>' \
  --run-command 'systemctl enable httpd' \
  --run-command 'firewall-offline-cmd --add-port=8404/tcp || true'
# Deliberately NOT labeling /srv/intranet and NOT labeling port 8404 — that is Task 33.

echo "== Starting VMs =="
# foxtrot is expected to drop to emergency — that IS Exam 3 Task 1.
for vm in rhel10-alpha rhel10-bravo rhel10-charlie rhel10-delta rhel10-echo rhel10-foxtrot; do
  sudo virsh start "${vm}"
done

echo "== Snapshotting exam-ready states =="
sudo virsh snapshot-create-as rhel10-alpha   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-bravo   exam1-ready "Exam 1 pristine"
sudo virsh snapshot-create-as rhel10-charlie exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-delta   exam2-ready "Exam 2 pristine"
sudo virsh snapshot-create-as rhel10-echo    exam3-ready "Exam 3 pristine: labdata + SELinux seeded"
sudo virsh snapshot-create-as rhel10-foxtrot exam3-ready "Exam 3 pristine: fstab broken + root scrambled"

echo "== DONE. All three exam environments ready. =="
```

> **⚠️ Run this after every golden-image update.** Before Exam 3 existed this script only rebuilt alpha/bravo/charlie/delta — running it left `echo`/`foxtrot` as stale clones of the *previous* golden image, with an `exam3-ready` snapshot pointing at pre-update state. You would then be practicing Exam 3 on a different base OS than Exams 1 and 2 without noticing.
>
> The Exam 3 seeding above is the `virt-customize` (offline) equivalent of the boot-and-run-by-hand blocks in `[[RHCSA Practice Exam 3 - RHEL 10]]`. Either path works — use whichever you prefer, but not both.

---

## 🚨 TROUBLESHOOTING

| Symptom                                                              | Cause / Fix                                                                                                                                        |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Disks show as`/dev/vdb`, not `/dev/sdb`                          | **Expected.** `add-disk.sh` attaches on the virtio bus, so the guest always names data disks `vdX`. All three exams' task text says `/dev/vdX` — pass `vdb`/`vdc`/`vdd` to the script and leave it alone |
| delta boots to multi-user, not rescue                                | `set-default rescue.target` did not apply — re-run the virt-customize step                                                                      |
| Cannot break into bravo/charlie                                      | Password was not scrambled — re-run with a fresh`openssl rand`                                                                                  |
| Exam VMs from different exams see each other                         | Wrong network — alpha/bravo on`rhcsa-net1`, charlie/delta on `rhcsa-net2`, echo/foxtrot on `rhcsa-net3`                                   |
| foxtrot drops to an emergency prompt on first boot                   | **Expected** — that is Exam 3 Task 1. Do not "fix" it during setup                                                                                 |
| `rhcsa-net3` undefined when building Exam 3                        | Phase 1 defines all three — re-run its net3 block, then`virsh net-list --all` to confirm it is active                                           |
| Exam 3 VMs are on an older OS than Exams 1 & 2                       | The full-rebuild script was run before it covered echo/foxtrot — re-run the current version, which rebuilds all six                                 |
| `snapshot-revert` fails: domain running                            | Run`virsh destroy <vm>` first, then revert                                                                                                       |
| Static IP task breaks SSH access                                     | Expected — use`virsh console` until the network task is done                                                                                    |
| Reboot test wipes a completed task                                   | The task was not made persistent — redo it correctly                                                                                              |
| GRUB edit will not accept the break-in args                          | Press`e` at the boot menu, edit the `linux` line, then `Ctrl+X`                                                                              |
| Extra disks missing after revert                                     | Snapshot was taken before disks attached — re-take the exam-ready snapshot                                                                        |
| `dnf repolist` shows no `BaseOS`/`AppStream`                   | DVD not attached or not mounted — check`virsh domblklist <vm>`, then `mount /dev/sr0 /mnt/rhel10iso` and `dnf clean all`                    |
| DVD ISO gone after`snapshot-revert`                                | Media was attached*after* the exam-ready snapshot — re-attach, then re-take the `examN-ready` snapshot                                        |
| Boot into emergency mode after adding ISO to`/etc/fstab`           | Hardcoded`/dev/sr0` mount with no disc present — add `nofail` to the fstab options                                                            |
| EPEL step (Task 13 "if connected") fails offline                     | Expected — EPEL is an internet-only Fedora repo and is**not** on the DVD; skip it in offline runs                                           |
| `curl`/API download returns null `href`                          | Access token expired (15-min life) or wrong checksum — re-run the token step and re-copy the**DVD** SHA-256                                 |
| Kickstart install hangs /`%packages` fails with "cannot find repo" | Used the**Boot ISO** with a kickstart — Boot ISO has no packages. Use the **DVD ISO** (`--location …-dvd.iso`) or switch to Path A |
| Path A: "Error setting up base repository"                           | Boot ISO can't reach packages — register via*Connect to Red Hat* or set a valid network Installation Source                                     |

---

## 📅 HOW THIS FITS THE CERT TIMELINE

Per `[[RHCA-Ansible-Cert-Path-Timeline]]`:

- RHCSA (EX200) is the prerequisite, **targeted mid-October 2026** *(moved from mid-September — European travel disrupted study more than planned)*.
- Use Exam 1 first (foundational methods: rd.break, fdisk, simple LVM).
- Use Exam 2 second (advanced variants: init=/bin/bash, parted, striped LVM, ACLs, rich rules).
- Use Exam 3 third (gap-fill: recovery, diagnosis, essential tools, skopeo — answer key is separated, so it is the only one that tests recall).
- Aim to pass all three practice exams at 30/35 or better before booking the real EX200.
- The `rhel10-golden` image built in Phase 0 is reused by the RHCA lab — the RHCA guide references it rather than rebuilding.

### Recommended drill cadence (Sep 9 → mid-October 2026)

| Week           | Dates          | Activity                                                                  |
| -------------- | -------------- | ------------------------------------------------------------------------- |
| Sep, week 2    | Sep 9–15       | Build echo/foxtrot; full timed run of **Exam 3** cold; self-grade          |
| Sep, week 3    | Sep 16–22      | Re-run **Exams 1 and 2 cold** — solutions covered. Recall, not recognition |
| Sep, week 4    | Sep 23–29      | Re-run Exam 3; drill only what failed twice across all three               |
| Sep 30 – Oct 6 | Oct, week 1    | All three back-to-back at 30/35+; **book the real EX200**                  |
| Oct, week 2    | Oct 7–14       | Light review; weak-area drills only; take real EX200                      |

> **Why the order changed:** Exams 1 and 2 were originally worked with their answers inline, which trains recognition. Exam 3 hides its key, so running it *first* gives an honest baseline — then Exams 1 and 2 get re-run cold to close the same gap.

---

## 🔗 Related Vault Notes

- 📄 `[[RHCSA Practice Exam 1 - RHEL 10]]` — 35 tasks, alpha/bravo
- 📄 `[[RHCSA Practice Exam 2 - RHEL 10]]` — 35 tasks, charlie/delta
- 📄 `[[RHCSA Practice Exam 3 - RHEL 10]]` — 35 tasks, echo/foxtrot; gap-fill, answer key at end
- 📄 `[[RHCA-Practice-Lab-Node-Setup-Guide]]` — reuses the golden image from Phase 0 here
- 📄 `[[RHCA-Ansible-Cert-Path-Timeline]]` — where RHCSA fits in the RHCA journey

---

*Setup and usage guide created 2026-07-08. Golden image build lives here; RHCA lab work builds on it. Covers RHCSA Practice Exam 1 (alpha/bravo) and Exam 2 (charlie/delta) on RHEL 10.*
