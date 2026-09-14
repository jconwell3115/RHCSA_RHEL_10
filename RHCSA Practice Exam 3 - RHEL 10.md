---
title: RHCSA Practice Exam 3 - RHEL 10
tags: [certifications, rhcsa, rhel10, practice, linux, gap-fill]
created: 2026-09-09
covers: [EX200 objectives untested by Practice Exams 1 and 2]
note: Answer key is at the BOTTOM of this file. Do not scroll past the Grading Checklist during a timed run.
---

# 🧪 RHCSA Practice Exam #3 — RHEL 10 (EX200) — Gap-Fill Edition

> **Format:** Performance-based | **Time budget:** 4 hours, or two sittings | **Pass Score:** 25 / 35
>
> All configurations **must persist after reboot** without intervention.
>
> You may use `man`, `info`, and `/usr/share/doc` — no internet access on exam day.

> **⏱️ This is a 4-hour paper, not a 2.5-hour one.** Tasks 7, 9, 10 and 27 each have six or seven sub-answers to capture, and Tasks 1, 4 and 33 are open-ended diagnosis with no hint of the cause. Splitting into two timed sittings (Sections 1–6, then 7–11) is the better drill. **Do not read a timer overrun here as "not ready"** — the real EX200 presents far fewer, larger tasks.
>
> **First cold run: expect 15–20 / 35.** Twenty-six of these tasks cover material Exams 1 and 2 never touched. A low first score is the diagnostic working, not a failure.

> **⚠️ This exam is deliberately different from Exams 1 and 2.**
> Roughly two-thirds of these tasks cover EX200 objectives that Exams 1 and 2 **never tested** — I/O redirection, `grep`/regex, `tar`/archives, system documentation, `skopeo`, SELinux violation *diagnosis*, service failure diagnosis, and unbootable-system recovery. The rest re-test core objectives through tools and angles you haven't used yet (`grubby`, `systemctl edit`, `dnf history`, `sfdisk` table dumps, LVM **shrink**, bind mounts, `/etc/cron.d`).
>
> **No hints or solutions appear beside the tasks.** The full answer key lives in a single section at the end. Exams 1 and 2 trained recognition; this one trains recall.

---

## 🖥️ Lab Environment Setup

### Required Virtual Machines

| VM                | vCPU | RAM  | Primary Disk       | Extra Disks                        |
| ----------------- | ---- | ---- | ------------------ | ---------------------------------- |
| `rhel10-echo`     | 2    | 2 GB | 20 GB `/dev/vda`   | 8 GB `/dev/vdb`, 6 GB `/dev/vdc`   |
| `rhel10-foxtrot`  | 2    | 2 GB | 20 GB `/dev/vda`   | 8 GB `/dev/vdb`                    |

### Network — third isolated subnet

| Host    | Hostname            | IPv4               | IPv6             | Gateway        | DNS                      |
| ------- | ------------------- | ------------------ | ---------------- | -------------- | ------------------------ |
| echo    | `echo.ex200.net`    | `172.16.40.21/24`  | `fd10::21/64`    | `172.16.40.1`  | `172.16.40.1, 1.1.1.1`   |
| foxtrot | `foxtrot.ex200.net` | `172.16.40.22/24`  | `fd10::22/64`    | `172.16.40.1`  | `172.16.40.1, 1.1.1.1`   |

### Build (clones from `rhel10-golden` — see `[[RHCSA Exam Lab Setup]]` Phase 0)

```bash
# Third network
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
sudo virsh net-define /tmp/rhcsa-net3.xml
sudo virsh net-autostart rhcsa-net3
sudo virsh net-start rhcsa-net3

# Clone the pair
sudo virt-clone --original rhel10-golden --name rhel10-echo \
  --file /home/libvirt/images/rhel10-echo.qcow2
sudo virt-clone --original rhel10-golden --name rhel10-foxtrot \
  --file /home/libvirt/images/rhel10-foxtrot.qcow2

for vm in rhel10-echo rhel10-foxtrot; do
  sudo virsh detach-interface "${vm}" network --config || true
  sudo virsh attach-interface "${vm}" network rhcsa-net3 --model virtio --config
done

# Memory / CPU — match Phases 3.3 and 4.3 in the lab guide
for vm in rhel10-echo rhel10-foxtrot; do
  sudo virsh setmaxmem "${vm}" 2048M --config
  sudo virsh setmem    "${vm}" 2048M --config
  sudo virsh setvcpus  "${vm}" 2 --config --maximum
  sudo virsh setvcpus  "${vm}" 2 --config
done

sudo virt-customize -d rhel10-echo    --hostname rhel10-echo
sudo virt-customize -d rhel10-foxtrot --hostname rhel10-foxtrot

# Extra disks (virtio bus → they appear as /dev/vdX inside the guest)
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-echo    vdb 8
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-echo    vdc 6
sudo ~/my_work_tools/bin/bash/add-disk.sh rhel10-foxtrot vdb 8

# DVD ISO to echo (Task 17 repo work)
sudo virsh change-media rhel10-echo sda \
  /home/libvirt/iso/rhel-10.2-x86_64-dvd.iso --insert --config
```

### 🔧 Seeding the broken conditions (do this BEFORE the exam-ready snapshot)

Exam 3 depends on three deliberately broken states. Boot each VM once, run its seed block, then shut down and snapshot.

**On `rhel10-foxtrot` — break the boot (Task 1):**

```bash
# Bogus UUID with no nofail → boot drops to emergency
echo "UUID=deadbeef-0000-0000-0000-000000000000 /mnt/archive xfs defaults 0 0" \
  | sudo tee -a /etc/fstab

# Scramble root so emergency.target's sulogin prompt is useless
sudo passwd root --stdin <<< "$(openssl rand -base64 24)" >/dev/null 2>&1 || \
  echo "root:$(openssl rand -base64 24)" | sudo chpasswd
sudo shutdown -h now
```

**On `rhel10-echo` — break a service (Task 4) and seed the SELinux violations (Task 33):**

```bash
# --- Task 4: a unit that will fail on boot ---
sudo tee /etc/systemd/system/labdata.service >/dev/null <<'EOF'
[Unit]
Description=Lab Data Collector
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/labdata-collect --daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable labdata.service

# --- Task 33: httpd pre-configured into TWO SELinux violations ---
sudo dnf install -y httpd policycoreutils-python-utils setroubleshoot-server
sudo mkdir -p /srv/intranet
echo "Echo Intranet OK" | sudo tee /srv/intranet/index.html >/dev/null
sudo tee /etc/httpd/conf.d/intranet.conf >/dev/null <<'EOF'
Listen 8404
<VirtualHost *:8404>
    DocumentRoot /srv/intranet
    <Directory /srv/intranet>
        Require all granted
    </Directory>
</VirtualHost>
EOF
# Deliberately do NOT label /srv/intranet and do NOT label port 8404.
sudo systemctl enable httpd
sudo firewall-cmd --permanent --add-port=8404/tcp && sudo firewall-cmd --reload
sudo shutdown -h now
```

**Then snapshot both:**

```bash
sudo virsh start rhel10-echo; sudo virsh start rhel10-foxtrot
for vm in rhel10-echo rhel10-foxtrot; do
  sudo virsh snapshot-create-as "${vm}" exam3-ready \
    "Exam 3 pristine: foxtrot fstab broken + root scrambled, echo labdata + SELinux seeded"
done
```

> **Reset for a retake:** `virsh destroy` then `virsh snapshot-revert <vm> exam3-ready`.

---

## 📋 Exam Instructions

1. Work the correct host — tasks are tagged `(echo)`, `(foxtrot)`, or `(both)`.
2. **Do not scroll to the answer key.** If you're stuck, use `man` — that's the skill being tested.
3. All configuration must survive a reboot unless the task says otherwise.
4. Where a task says "record the answer in `<file>`", the grader checks that file — the command alone isn't credit.
5. Budget ~4 minutes per task. Flag anything over 8 minutes and come back.

---

## 🚀 PRACTICE EXAM #3 — 35 TASKS

---

### SECTION 1: Boot Failure, Recovery & Service Diagnosis

---

**Task 1 — Recover an Unbootable System** *(foxtrot)*

`rhel10-foxtrot` no longer boots — it drops to an emergency prompt. The root password is also unknown, so the emergency shell's login prompt is useless to you.

1. Gain access to the system
2. Identify why the boot fails (the cause is in a configuration file)
3. Repair it so the system boots unattended
4. Set the root password to `Ex3Recovery!`
5. Ensure SELinux labels remain correct for any file you edited
6. Reboot and confirm a clean multi-user boot with no manual intervention

---

**Task 2 — One-Shot Boot Into a Different Target** *(foxtrot)*

Without changing the system's default target:

1. Boot `foxtrot` **once** into `rescue.target` using a GRUB kernel argument
2. From that shell, record the output of `systemctl get-default` into `/root/target_check.txt`
3. Reboot normally and confirm the system returns to its usual default target on its own

---

**Task 3 — Manage Kernel Arguments With `grubby`** *(echo)*

Do **not** hand-edit `/etc/default/grub` for this task.

1. List the currently installed kernels and identify the default one
2. Persistently add the kernel arguments `audit=1` and `transparent_hugepage=never` to **all** installed kernels
3. Persistently remove `rhgb` and `quiet` from all installed kernels
4. Reboot and verify with `/proc/cmdline`
5. Record the resulting `/proc/cmdline` in `/root/cmdline.txt`

---

**Task 4 — Diagnose and Repair a Failed Service** *(echo)*

A service named `labdata.service` is enabled but fails to start.

1. Determine that it failed and capture the reason — save the diagnostic output to `/root/labdata_diag.txt`
2. Identify the specific missing dependency causing the failure
3. Create the missing component so the service starts successfully. It must run continuously and write the current date to `/var/log/labdata.log` once per minute
4. Ensure the service is running and starts automatically at boot
5. Confirm it is active after a reboot

---

**Task 5 — Override a Unit With a systemd Drop-In** *(echo)*

Without editing the vendor-supplied unit file, override `sshd.service`:

1. Add a drop-in so `sshd` restarts automatically 30 seconds after any failure
2. Add a custom `Description` of `SSH Daemon (lab-tuned)`
3. Verify the override is being read and identify the exact path of the file you created
4. Record the output of `systemctl show sshd.service -p Restart -p RestartSec -p Description` into `/root/sshd_override.txt`
5. Demonstrate how you would discard all overrides for a unit (document the command in the same file — do **not** actually run it)

---

### SECTION 2: Essential Tools

> This entire section covers EX200 objectives that Exams 1 and 2 never tested.

---

**Task 6 — Input/Output Redirection** *(echo)*

Working in `/root`:

1. Run `ls /etc /nonexistent` so that **stdout only** goes to `/root/redir_out.txt` and **stderr only** goes to `/root/redir_err.txt`
2. Run the same command so that stdout **and** stderr both land in `/root/redir_both.txt` in a single file
3. Append the current date to `/root/redir_out.txt` without truncating it
4. Run `df -h` so the output is written to `/root/df_report.txt` **and** displayed on your terminal at the same time
5. Run `find /etc -name '*.conf'` discarding all error messages but keeping the results in `/root/conf_list.txt`
6. Use a here-document to create `/root/notes.txt` containing three lines of your choice

---

**Task 7 — grep and Regular Expressions** *(echo)*

Save each answer to the file named in brackets:

1. Every line in `/etc/passwd` for a user with a UID of exactly four digits `[/root/g1.txt]`
2. Every line in `/etc/ssh/sshd_config` that is **not** a comment and **not** blank `[/root/g2.txt]`
3. A count (number only) of how many users use `/sbin/nologin` as their shell `[/root/g3.txt]`
4. Every IPv4 address appearing anywhere in `/var/log/`, listed once each, printing **only the address** and not the whole line `[/root/g4.txt]`
5. Every line in `/etc/services` beginning with `http` followed by any character other than `s` `[/root/g5.txt]`
6. All files under `/etc` containing the case-insensitive string `selinux`, showing filename and line number `[/root/g6.txt]`

---

**Task 8 — Locating Files With `find`** *(echo)*

Save results to the indicated files:

1. All files under `/var` larger than 5 MB `[/root/f1.txt]`
2. All files under `/etc` modified in the last 7 days `[/root/f2.txt]`
3. All files anywhere under `/home` and `/srv` owned by user `emma` (create `emma` if needed) `[/root/f3.txt]`
4. All directories under `/etc` with permissions exactly `0700` `[/root/f4.txt]`
5. All `*.log` files under `/var/log` older than 3 days, copied — not moved — into `/root/oldlogs/` in a **single** `find` command
6. All empty files under `/tmp`, deleted in a single command

---

**Task 9 — Archives and Compression** *(echo)*

1. Create a **gzip**-compressed tar archive of `/etc/ssh` at `/root/ssh_backup.tar.gz`
2. Create a **bzip2**-compressed tar archive of the same directory at `/root/ssh_backup.tar.bz2`
3. Compare the two file sizes and record which is smaller in `/root/compression.txt`
4. List the contents of the gzip archive **without extracting it**, saving the listing to `/root/archive_list.txt`
5. Extract **only** `etc/ssh/sshd_config` from the gzip archive into `/root/restore/`
6. Create an archive of `/var/log` at `/root/logs.tar.gz` that **excludes** everything under `/var/log/journal`
7. Extract `/root/ssh_backup.tar.bz2` into `/root/restore_full/`, preserving permissions

---

**Task 10 — Use the System Documentation** *(echo)*

No internet. Answer each using only on-system documentation, writing answers into `/root/docs_answers.txt` (one numbered line each):

1. Which manual **section** documents the `passwd` **file format** (as opposed to the command)?
2. Search all man pages for ones whose description mentions "partition table" — list the command names
3. What `journalctl` option limits output to the current boot? Cite the man page you found it in
4. Name any file under `/usr/share/doc/` that documents `chrony`, giving its full path
5. Using `info`, name the top-level node listing for the `coreutils` documentation
6. Which config file does `man 5 fstab` say is described, and what is the **sixth** field used for?

---

### SECTION 3: Users, Groups & Permissions

---

**Task 11 — Users With a Customized Skeleton** *(echo)*

1. Add a file `/etc/skel/lab_welcome.txt` containing `Welcome to the EX200 lab` and a directory `/etc/skel/projects/`
2. Create group `research` with GID `7000`
3. Create users `emma` (UID 3100) and `noah` (UID 3101), both with primary group `research`
4. Confirm both received the skeleton content in their home directories
5. Create user `oscar` (UID 3102) whose home directory is `/opt/oscar` and confirm the skeleton content was placed there too
6. Move `noah`'s home directory to `/srv/homes/noah` **with its existing contents**, and verify `noah` can still log in and lands there

---

**Task 12 — sudo Defaults and Logging** *(echo)*

Create `/etc/sudoers.d/lab3_defaults`:

1. The `research` group may run all commands, with a password
2. Set a `Defaults` entry so sudo credentials are cached for `0` minutes (password every time) for the `research` group
3. Set a `Defaults` entry logging all sudo activity to `/var/log/sudo_lab.log`
4. Set a `Defaults` entry adding `/usr/local/lab/bin` to sudo's `secure_path`
5. Validate the file syntax before it takes effect, and verify with `sudo -l -U emma`

---

**Task 13 — ACL Masks and Default Inheritance** *(echo)*

Create `/srv/shared/data`, owned by `emma:research`, mode `2770`:

1. Grant `noah` `rwx` via an access ACL **and** a default ACL
2. Grant group `wheel` `r-x` via an access ACL **and** a default ACL
3. Set the ACL **mask** to `r-x` and record — in `/root/acl_effective.txt` — what `noah`'s *effective* permissions become and why
4. Create a file inside as `emma` and show the default ACL was inherited
5. Restore the mask to `rwx` and confirm `noah`'s effective permissions change back

---

**Task 14 — SELinux Contexts: `cp` vs `mv`** *(echo)*

1. Create `/root/site_index.html` containing `Context Test`
2. Record its SELinux context in `/root/context_report.txt`
3. **Copy** it to `/var/www/html/copied.html`; record the resulting context
4. **Move** a second identical file to `/var/www/html/moved.html`; record the resulting context
5. Explain in the same report which operation produced the wrong context for httpd and why
6. Fix the incorrect file using the policy-driven tool (not `chcon`)
7. Copy a third file to `/var/www/html/preserved.html` in a way that **deliberately keeps** the source context, and note the option used

---

### SECTION 4: Networking

---

**Task 15 — Two Connection Profiles and Resolution Order** *(echo)*

1. Configure the primary connection as a profile named `lab3-static` with the IPv4 address, **IPv6 address**, gateway, and DNS from the environment table; it must autoconnect at boot
2. Create a **second** profile named `lab3-dhcp` on the same interface set to DHCP for IPv4 and automatic for IPv6, with autoconnect **disabled**
3. Demonstrate switching between the two profiles and switching back to `lab3-static`
4. Add both hosts to `/etc/hosts`
5. Explain in `/root/resolution.txt`: which file controls the *order* in which hostname lookups consult files vs DNS, and which line in it applies
6. Verify `foxtrot` resolves and responds by short hostname

---

**Task 16 — Firewalld Port Forwarding and Masquerade** *(echo)*

1. Ensure `httpd` is installed, enabled, and serving on port `80`
2. In the default zone, permanently forward incoming TCP port `8888` to local port `80`
3. Enable masquerading permanently in that zone
4. Permanently allow the `http` service
5. Reload and verify with `firewall-cmd --list-all`
6. Confirm from `foxtrot` that `curl http://echo.ex200.net:8888` reaches the web server

---

### SECTION 5: Software Management

---

**Task 17 — Repository Setup and Package Queries** *(echo)*

1. Mount the RHEL 10 DVD persistently at `/mnt/dvd` (must not block boot if the disc is absent)
2. Create a single repo file `/etc/yum.repos.d/lab3.repo` defining `BaseOS` and `AppStream` from that mount, with `gpgcheck=1` using the key on the media
3. Verify with `dnf repolist`
4. Determine which **package** provides the file `/usr/bin/semanage` `[/root/q1.txt]`
5. Determine which **package** owns the already-installed file `/etc/chrony.conf` `[/root/q2.txt]`
6. List every file the `chrony` package installs `[/root/q3.txt]`
7. Search for packages whose summary mentions "network manager" `[/root/q4.txt]`

---

**Task 18 — Transaction History and Rollback** *(echo)*

1. Install the `tmux` package
2. Display the transaction history and identify the ID of that installation `[/root/history_id.txt]`
3. Show the detailed contents of that transaction
4. **Undo** that transaction using `dnf`'s history mechanism — do not use `dnf remove`
5. Confirm `tmux` is no longer installed
6. Redo the transaction to reinstall it, again using the history mechanism

---

**Task 19 — RPM-Level Operations** *(echo)*

1. Download — do not install — the `zsh` RPM into `/root/rpms/`
2. Without installing it, list the files the package **would** install `[/root/rpm1.txt]`
3. Without installing it, display the package's scriptlets `[/root/rpm2.txt]`
4. Extract **only** the `zsh` man page from the RPM into `/root/extracted/` without installing the package
5. Verify the package signature
6. Install it, then verify the installed package reports no modifications

---

### SECTION 6: Storage

---

**Task 20 — GPT Partitioning and Type Codes With `fdisk`** *(echo, `/dev/vdb`)*

Exam 1 drove `fdisk` interactively and Exam 2 used `parted -s`. This time, use `fdisk` but focus on **partition type codes** and on capturing the layout in a machine-readable form.

1. Create a fresh GPT table on `/dev/vdb`
2. Create `vdb1` = 3 GiB, type **Linux filesystem**
3. Create `vdb2` = 2 GiB, type **Linux LVM** — you must change the type, not accept the default
4. Inform the kernel, then verify with `lsblk` and `fdisk -l`
5. Dump the partition table — including each partition's **type GUID and PARTUUID** — to `/root/gpt_layout.txt`
6. Save a restorable backup of the partition table to `/root/vdb-parttable.bak`, and record in `/root/gpt_layout.txt` the command that would restore it

---

**Task 21 — Shrink a Logical Volume** *(echo, `/dev/vdb2` + `/dev/vdc`)*

1. Create PVs on `/dev/vdb2` and `/dev/vdc`, and VG `vg_ex3` with an 8 MiB PE size
2. Create LV `lv_shrink` of **4 GiB**, formatted **ext4**, mounted persistently at `/mnt/shrink`
3. Write a test file into it and record a checksum of that file
4. Shrink `lv_shrink` — filesystem **and** logical volume — to **2 GiB**
5. Remount it and prove the test file is intact by comparing the checksum
6. Record in `/root/shrink_notes.txt` why this task could not have been done had the filesystem been XFS

---

**Task 22 — Replace Swap Cleanly** *(foxtrot, `/dev/vdb`)*

1. Record the current swap configuration `[/root/swap_before.txt]`
2. Create a 1 GiB partition `/dev/vdb1` and format it as swap with the label `EX3SWAP`
3. Add it to `/etc/fstab` **by LABEL** with priority `5`
4. Activate it and verify both the label and the priority are in effect
5. Deactivate and permanently remove the **original** swap device from the system — it must not return after reboot
6. Reboot and confirm only `EX3SWAP` is active `[/root/swap_after.txt]`

---

**Task 23 — Mount Options and Live Remount** *(foxtrot)*

1. Create a 2 GiB partition `/dev/vdb2`, format XFS, mount persistently at `/data/vault` with options `noexec,nosuid,nodev`
2. Copy any executable binary into `/data/vault` and demonstrate it will not execute; record the error `[/root/noexec_proof.txt]`
3. Remount `/data/vault` **read-only without unmounting it** and prove writes fail
4. Remount it read-write again, still without unmounting
5. Use `findmnt` to display the active options and save them `[/root/mount_opts.txt]`

---

**Task 24 — Bind Mount in fstab** *(foxtrot)*

1. Create `/srv/appdata` containing a file `payload.txt`
2. Create `/opt/app/data`
3. Configure a **bind mount** in `/etc/fstab` so `/srv/appdata` also appears at `/opt/app/data`
4. Activate it without rebooting and confirm `payload.txt` is visible at both paths
5. Reboot and confirm the bind mount returns automatically

---

### SECTION 7: NFS & AutoFS

---

**Task 25 — NFS Server With a Diagnostic Step** *(foxtrot)*

1. Install `nfs-utils`, create `/export/team` owned appropriately for group write access
2. Export it read/write to `172.16.40.0/24`
3. Start and enable `nfs-server`, and open the firewall for `nfs`, `mountd`, and `rpc-bind`
4. Deliberately introduce a typo in `/etc/exports` (e.g. a space between the client and its options), re-export, and record what changes about the resulting export `[/root/exports_typo.txt]`
5. Fix the typo, re-export, and verify the correct options with `exportfs -v`
6. Confirm from `echo` that the share can be listed remotely

---

**Task 26 — AutoFS With an Indirect Map** *(echo)*

1. On `foxtrot`, export `/export/team` (from Task 25) to the lab subnet
2. On `echo`, install `autofs` and configure an **indirect** map so `foxtrot:/export/team` mounts on demand at `/net/team`
3. Set the idle unmount timeout to `45` seconds
4. Enable and start `autofs`
5. Trigger the mount by accessing the path, and confirm it appears in `findmnt`
6. Confirm it unmounts itself after the idle period

---

### SECTION 8: Services, Logging, Time & Scheduling

---

**Task 27 — Journal Filtering by Time and Field** *(echo)*

Save each result to the indicated file:

1. All journal entries from the current boot for `sshd` only `[/root/j1.txt]`
2. All entries between `09:00` and `12:00` today `[/root/j2.txt]`
3. All entries since yesterday at priority `err` or worse `[/root/j3.txt]`
4. All entries generated by the `sudo` command, matched by the command field rather than the unit `[/root/j4.txt]`
5. The current on-disk size of the journal `[/root/j5.txt]`
6. Reduce the stored journal so it retains no more than `200M`, and cap it at `200M` permanently in the journald configuration

---

**Task 28 — Persistent Kernel Parameters** *(echo)*

Using a drop-in file — do **not** edit `/etc/sysctl.conf`:

1. Set `net.ipv4.ip_forward = 1`
2. Set `vm.swappiness = 20`
3. Set `kernel.pid_max = 65536`
4. Apply them without rebooting
5. Verify each is live, and record the values in `/root/sysctl_verify.txt`
6. Reboot and confirm all three survived

---

**Task 29 — `at`, Access Control, and `/etc/cron.d`** *(echo)*

1. Ensure `atd` is running. Schedule a job for 10 minutes from now that appends `at job ran` to `/var/log/at3.log`
2. List the queue, then display the **contents** of that queued job `[/root/at_job.txt]`
3. Delete the job and confirm the queue is empty
4. Configure `at` so that **only** user `emma` may submit jobs — no other non-root user
5. Create a job in `/etc/cron.d/labreport` (not a user crontab) that runs `/usr/local/bin/labreport.sh` **as user `emma`** every Monday and Thursday at 05:45
6. Explain in `/root/crond_note.txt` how a `/etc/cron.d` entry differs in format from a user crontab entry

---

**Task 30 — Time Synchronization** *(both)*

1. On `foxtrot`, configure `chrony` to serve time to `172.16.40.0/24` and open the firewall for NTP
2. On `echo`, configure `chrony` to use **only** `foxtrot` as its time source
3. Verify from `echo` that `foxtrot` is the selected source
4. Set the hardware clock policy so the system uses UTC, and set `echo`'s timezone to `America/Denver`
5. Record `timedatectl` output on `echo` `[/root/time_status.txt]`

---

### SECTION 9: Shell Scripting

---

**Task 31 — Script With Strict Mode and Exit Codes** *(echo)*

Write `/usr/local/bin/diskwatch.sh`:

- Enable strict error handling (`set -euo pipefail`)
- Accepts exactly one argument: a mount point
- If no argument is given → usage message to **stderr**, exit `2`
- If the argument is not a currently mounted path → `"Not mounted: <arg>"` to **stderr**, exit `3`
- If usage of that filesystem is at or above 80% → print `CRITICAL: <arg> at NN%`, exit `1`
- Otherwise print `OK: <arg> at NN%`, exit `0`
- Test all four paths and record each exit code in `/root/diskwatch_tests.txt`

---

**Task 32 — Text Processing Report Script** *(echo)*

Write `/usr/local/bin/userreport.sh` that produces a report at `/var/log/userreport.txt` containing:

- Total number of accounts with a **valid login shell** (not `nologin` or `false`)
- The five highest UIDs on the system with their usernames
- Every group that currently has **no** members listed in `/etc/group`
- A count of accounts whose passwords are locked
- All values must be derived by processing command/file output — no hard-coded numbers
- Run it and confirm the report is populated

---

### SECTION 10: SELinux

---

**Task 33 — Diagnose SELinux Violations From Scratch** *(echo)*

`httpd` is installed and configured to serve `/srv/intranet` on port `8404`, but it does not work. You are **not** told what is wrong.

1. Attempt to start `httpd` and capture the failure `[/root/selinux_diag.txt]`
2. Use the audit tools to identify **every** SELinux denial involved — there is more than one distinct problem
3. Use the tool that explains *why* a denial occurred, and record its explanation in the same file
4. Fix each problem using the correct persistent mechanism for that problem type
5. Start `httpd`, confirm `curl http://localhost:8404/` returns `Echo Intranet OK`
6. Confirm no new denials are generated, and that everything survives a reboot

---

**Task 34 — Build and Install a Local Policy Module** *(echo)*

> Stretch task — beyond typical EX200 depth, but directly in service of "diagnose and address routine SELinux policy violations."

1. Ensure SELinux is `enforcing`
2. Generate a denial: have `httpd` attempt something the policy forbids (for example, reading a file labeled `admin_home_t` placed in its document root)
3. Confirm the denial appears in the audit log
4. Generate a **named local policy module** from that denial called `labhttpd`
5. Install the module and confirm it appears in the module list
6. Verify the action now succeeds
7. Record in `/root/policy_module.txt` why `restorecon` or a boolean would usually be the better fix

---

### SECTION 11: Containers

---

**Task 35 — Registry Tooling and a Self-Updating Rootless Container** *(echo, as user `emma`)*

1. As `root`, ensure `podman` and `skopeo` are installed and enable **lingering** for `emma`
2. As `emma`, use **`skopeo`** — not `podman` — to inspect `docker://registry.access.redhat.com/ubi10/ubi:latest` and record the image digest and available labels `[/home/emma/skopeo_inspect.txt]`
3. Use `skopeo` to list the available tags for that repository `[/home/emma/skopeo_tags.txt]`
4. Authenticate to `registry.redhat.io` with `podman login` and record where the credentials file is stored `[/home/emma/auth_path.txt]` *(if offline, document the exact command and expected path instead)*
5. Create a podman volume `emma-site` and place an `index.html` in it containing `Echo Container OK`
6. Create a **Quadlet** at `~/.config/containers/systemd/emma-site.container` that:
   - runs `registry.access.redhat.com/ubi10/httpd-24`
   - publishes host port `9191` to the container's HTTP port
   - mounts the `emma-site` volume at the web root with the correct SELinux relabel flag
   - sets the environment variable `LAB_ENV=exam3`
   - enables **automatic image updates** from the registry
7. Start the service, verify with `curl http://localhost:9191/`
8. Enable the rootless timer that performs automatic updates
9. Reboot and confirm the container starts with no login from `emma`

---

## 📊 Grading Checklist

| #  | Task                                              | Gap-fill | Reboot Test | Done |
| -- | ------------------------------------------------- | :------: | :---------: | :--: |
| 1  | Recover unbootable system (broken fstab)          |    ★    |      ✓      | [ ] |
| 2  | One-shot boot to rescue.target via GRUB           |    ★    |      —      | [ ] |
| 3  | Kernel args via `grubby`                          |    ★    |      ✓      | [ ] |
| 4  | Diagnose + repair failed service                  |    ★    |      ✓      | [ ] |
| 5  | systemd drop-in override                          |    ★    |      ✓      | [ ] |
| 6  | I/O redirection (stdout/stderr/tee/heredoc)       |    ★    |      —      | [ ] |
| 7  | grep + regular expressions                        |    ★    |      —      | [ ] |
| 8  | `find` with size/time/owner/perm/-exec            |    ★    |      —      | [ ] |
| 9  | tar + gzip + bzip2, list/extract/exclude          |    ★    |      —      | [ ] |
| 10 | System documentation lookups                      |    ★    |      —      | [ ] |
| 11 | Users w/ custom skel + home relocation            |          |      ✓      | [ ] |
| 12 | sudo Defaults (timeout, logfile, secure_path)     |    ★    |      ✓      | [ ] |
| 13 | ACL mask + default inheritance                    |    ★    |      ✓      | [ ] |
| 14 | SELinux context: cp vs mv                         |    ★    |      ✓      | [ ] |
| 15 | Two nmcli profiles + resolution order             |    ★    |      ✓      | [ ] |
| 16 | Firewalld port forward + masquerade               |    ★    |      ✓      | [ ] |
| 17 | Repo w/ GPG + dnf provides/whatprovides/search    |    ★    |      ✓      | [ ] |
| 18 | `dnf history` undo / redo                         |    ★    |      —      | [ ] |
| 19 | RPM query uninstalled + rpm2cpio extract          |    ★    |      —      | [ ] |
| 20 | GPT type codes + `sfdisk` dump/backup             |    ★    |      ✓      | [ ] |
| 21 | **Shrink** an ext4 LV                             |    ★    |      ✓      | [ ] |
| 22 | Replace swap + remove original                    |    ★    |      ✓      | [ ] |
| 23 | noexec proof + live remount ro/rw                 |    ★    |      ✓      | [ ] |
| 24 | Bind mount in fstab                               |    ★    |      ✓      | [ ] |
| 25 | NFS server + exports diagnostic                   |    ★    |      ✓      | [ ] |
| 26 | AutoFS indirect map w/ 45s timeout                |          |      ✓      | [ ] |
| 27 | journalctl time/field filtering + vacuum          |    ★    |      ✓      | [ ] |
| 28 | Persistent sysctl drop-in                         |    ★    |      ✓      | [ ] |
| 29 | at + at.allow + /etc/cron.d                       |    ★    |      ✓      | [ ] |
| 30 | Chrony server/client + timezone                   |          |      ✓      | [ ] |
| 31 | Script w/ strict mode + exit codes                |    ★    |      —      | [ ] |
| 32 | Text-processing report script                     |    ★    |      —      | [ ] |
| 33 | **Diagnose** SELinux denials unaided              |    ★    |      ✓      | [ ] |
| 34 | Build/install local policy module                 |    ★    |      ✓      | [ ] |
| 35 | skopeo + podman login + AutoUpdate Quadlet        |    ★    |      ✓      | [ ] |

**Score: ___ / 35**  ·  **Pass: 25 / 35**  ·  ★ = objective or scenario untested by Exams 1 & 2 (**26 of 35**)

---

## ✅ Quick Verification Script

Run on the relevant host **after a reboot**. Checks the objectively-verifiable, persistence-sensitive items only — it is a safety net, not a full grader.

```bash
#!/usr/bin/env bash
# ex3-verify.sh — spot-check Exam 3 persistence. Run with sudo on each host.
pass=0; fail=0
chk() { # chk "label" "command"
  # NOTE: pass=$((pass+1)), not ((pass++)) — the latter returns non-zero on the
  # first increment and would abort the script if anyone adds `set -e`.
  if eval "$2" &>/dev/null; then printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1))
  else printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); fi
}

echo "== Host: $(hostname -s) =="

case "$(hostname -s)" in
  *echo*)
    chk "T3  kernel args applied"      "grep -q 'audit=1' /proc/cmdline && ! grep -q ' quiet' /proc/cmdline"
    chk "T4  labdata.service active"   "systemctl is-active --quiet labdata.service"
    chk "T5  sshd drop-in present"     "test -f /etc/systemd/system/sshd.service.d/override.conf"
    chk "T5  RestartSec=30"            "systemctl show sshd -p RestartSec | grep -q 30"
    chk "T11 emma uid 3100"            "id -u emma | grep -qx 3100"
    chk "T11 noah home relocated"      "getent passwd noah | grep -q /srv/homes/noah"
    chk "T13 default ACL on share"     "getfacl /srv/shared/data 2>/dev/null | grep -q '^default:user:noah'"
    chk "T15 lab3-static autoconnect"  "nmcli -g connection.autoconnect con show lab3-static | grep -qi yes"
    chk "T15 IPv6 address configured"  "ip -6 addr show | grep -q 'fd10::21'"
    chk "T20 partition backup saved"   "test -s /root/vdb-parttable.bak"
    chk "T16 forward port 8888"        "firewall-cmd --list-forward-ports | grep -q 8888"
    chk "T16 masquerade on"            "firewall-cmd --query-masquerade"
    chk "T17 dvd mounted"              "findmnt /mnt/dvd"
    chk "T17 repos enabled"            "dnf repolist 2>/dev/null | grep -qi appstream"
    chk "T21 lv_shrink is 2G"          "lvs --noheadings -o lv_size vg_ex3/lv_shrink | grep -q '2\\.00g'"
    chk "T21 /mnt/shrink mounted"      "findmnt /mnt/shrink"
    chk "T26 autofs enabled"           "systemctl is-enabled --quiet autofs"
    chk "T28 ip_forward=1"             "sysctl -n net.ipv4.ip_forward | grep -qx 1"
    chk "T28 swappiness=20"            "sysctl -n vm.swappiness | grep -qx 20"
    chk "T28 pid_max=65536"            "sysctl -n kernel.pid_max | grep -qx 65536"
    chk "T28 drop-in not sysctl.conf"  "ls /etc/sysctl.d/*.conf >/dev/null 2>&1"
    chk "T29 at.allow restricts"       "grep -qx emma /etc/at.allow"
    chk "T29 cron.d job present"       "grep -q emma /etc/cron.d/labreport"
    chk "T33 port 8404 labeled"        "semanage port -l | grep http_port_t | grep -q 8404"
    chk "T33 intranet fcontext"        "ls -Zd /srv/intranet | grep -q httpd_sys_content_t"
    chk "T33 httpd serving"            "curl -sf http://localhost:8404/ | grep -q 'Echo Intranet OK'"
    chk "T34 labhttpd module loaded"   "semodule -l | grep -qx labhttpd"
    chk "T35 linger enabled for emma"  "loginctl show-user emma -p Linger | grep -qi yes"
    chk "T35 container serving 9191"   "curl -sf http://localhost:9191/ | grep -q 'Echo Container OK'"
    ;;
  *foxtrot*)
    chk "T1  boots clean / fstab sane" "mount -a"
    chk "T22 EX3SWAP active"           "swapon --show=LABEL --noheadings | grep -q EX3SWAP"
    chk "T22 priority 5"               "swapon --show=PRIO --noheadings | grep -q 5"
    chk "T22 original swap gone"       "test \$(swapon --show --noheadings | wc -l) -eq 1"
    chk "T23 /data/vault noexec"       "findmnt -no OPTIONS /data/vault | grep -q noexec"
    chk "T24 bind mount active"        "findmnt /opt/app/data | grep -q srv/appdata"
    chk "T25 nfs-server running"       "systemctl is-active --quiet nfs-server"
    chk "T25 export present"           "exportfs -v | grep -q /export/team"
    chk "T30 chrony serving subnet"    "grep -qE '^allow +172\\.16\\.40\\.0/24' /etc/chrony.conf"
    ;;
esac

echo "== $pass passed, $fail failed =="
```

---

---

# 🔑 ANSWER KEY

> **Stop.** Do not read this during a timed run. Score yourself from the checklist first, then come back here for the tasks you missed.

---

### Section 1 — Boot Failure, Recovery & Service Diagnosis

**T1 — Recover an unbootable system**

The root password is unknown, so `emergency.target`'s `sulogin` prompt is a dead end. Break in below systemd:

```bash
# At GRUB: press 'e', find the linux line, change ro→rw, append init=/bin/bash, Ctrl-X
mount -o remount,rw /          # if not already rw
vi /etc/fstab                  # delete (or comment) the bogus UUID line
passwd root                    # set Ex3Recovery!
touch /.autorelabel            # SELinux relabel — you edited files without policy loaded
exec /sbin/reboot -f           # or: sync; exec /sbin/init
```

The failing line is the `UUID=deadbeef-...` entry: a nonexistent device with no `nofail`, so `local-fs.target` fails and boot stops. Adding `nofail` is the alternative fix if the mount is meant to stay defined.

**T2 — One-shot boot to rescue.target**

```bash
# At GRUB: 'e', append to the linux line, then Ctrl-X:
systemd.unit=rescue.target
# In the rescue shell:
systemctl get-default > /root/target_check.txt   # still shows multi-user.target
reboot
```

A kernel argument applies to that boot only — `systemctl set-default` is what would make it permanent, and you deliberately did not run it.

**T3 — grubby**

```bash
grubby --info=ALL
grubby --default-kernel
sudo grubby --update-kernel=ALL --args="audit=1 transparent_hugepage=never"
sudo grubby --update-kernel=ALL --remove-args="rhgb quiet"
sudo reboot
cat /proc/cmdline > /root/cmdline.txt
```

**T4 — Failed service**

```bash
systemctl status labdata.service > /root/labdata_diag.txt
journalctl -xeu labdata.service >> /root/labdata_diag.txt
# Reason: ExecStart=/usr/local/sbin/labdata-collect does not exist (status=203/EXEC)

sudo tee /usr/local/sbin/labdata-collect >/dev/null <<'EOF'
#!/bin/bash
while true; do
    date >> /var/log/labdata.log
    sleep 60
done
EOF
sudo chmod +x /usr/local/sbin/labdata-collect
sudo restorecon -v /usr/local/sbin/labdata-collect
sudo systemctl daemon-reload
sudo systemctl enable --now labdata.service
systemctl is-active labdata.service
```

The unit passes `--daemon`; the script ignores unknown arguments, which is fine. `203/EXEC` always means "the binary named in ExecStart could not be executed" — missing, not executable, or bad interpreter.

**T5 — Drop-in override**

```bash
sudo systemctl edit sshd.service
```
Creates `/etc/systemd/system/sshd.service.d/override.conf`:

```ini
[Unit]
Description=SSH Daemon (lab-tuned)

[Service]
Restart=on-failure
RestartSec=30
```

```bash
sudo systemctl daemon-reload
systemctl show sshd.service -p Restart -p RestartSec -p Description > /root/sshd_override.txt
echo "# To discard all overrides: systemctl revert sshd.service" >> /root/sshd_override.txt
systemctl cat sshd.service      # shows vendor unit + drop-in and their paths
```

> Gotcha worth knowing: overriding a **list-valued** directive like `ExecStart=` requires clearing it first with an empty `ExecStart=` line, then setting the new value. Scalar directives like `Restart=` simply replace.

---

### Section 2 — Essential Tools

**T6 — Redirection**

```bash
ls /etc /nonexistent > /root/redir_out.txt 2> /root/redir_err.txt
ls /etc /nonexistent > /root/redir_both.txt 2>&1     # order matters
date >> /root/redir_out.txt
df -h | tee /root/df_report.txt
find /etc -name '*.conf' 2>/dev/null > /root/conf_list.txt
cat > /root/notes.txt <<'EOF'
line one
line two
line three
EOF
```

`> file 2>&1` works; `2>&1 > file` does **not** — the duplication happens before stdout is redirected. `&> file` is the bash shorthand.

**T7 — grep and regex**

```bash
grep -E ':[0-9]{4}:' /etc/passwd > /root/g1.txt
grep -vE '^\s*(#|$)' /etc/ssh/sshd_config > /root/g2.txt
grep -c '/sbin/nologin$' /etc/passwd > /root/g3.txt
grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' /var/log/ 2>/dev/null | sort -u > /root/g4.txt
grep -E '^http[^s]' /etc/services > /root/g5.txt
grep -rin 'selinux' /etc/ 2>/dev/null > /root/g6.txt
```

Key pieces: `-E` for extended regex, `-o` prints only the match, `-h` suppresses filenames, `-c` counts, `-v` inverts, `-r` recurses, `-n` adds line numbers, `-i` ignores case. `[^s]` is "any character except s".

**T8 — find**

```bash
find /var -type f -size +5M > /root/f1.txt
find /etc -type f -mtime -7 > /root/f2.txt
find /home /srv -user emma > /root/f3.txt
find /etc -type d -perm 0700 > /root/f4.txt

mkdir -p /root/oldlogs
find /var/log -name '*.log' -mtime +3 -exec cp {} /root/oldlogs/ \;
find /tmp -type f -empty -delete
```

`-perm 0700` = exactly those bits; `-perm -0700` = at least those bits; `-perm /0700` = any of them. `-exec ... \;` runs once per file, `-exec ... +` batches (faster, but the batching form puts filenames at the end so it doesn't suit `cp` to a destination without `-t`).

**T9 — Archives**

```bash
tar czf /root/ssh_backup.tar.gz /etc/ssh
tar cjf /root/ssh_backup.tar.bz2 /etc/ssh
ls -l /root/ssh_backup.tar.* > /root/compression.txt   # bzip2 is normally smaller
tar tzf /root/ssh_backup.tar.gz > /root/archive_list.txt

mkdir -p /root/restore
tar xzf /root/ssh_backup.tar.gz -C /root/restore etc/ssh/sshd_config

tar czf /root/logs.tar.gz --exclude='/var/log/journal' /var/log

mkdir -p /root/restore_full
tar xjpf /root/ssh_backup.tar.bz2 -C /root/restore_full
```

`c`=create, `x`=extract, `t`=list, `z`=gzip, `j`=bzip2, `J`=xz, `f`=file, `p`=preserve permissions, `-C`=change to directory. Paths inside the archive are relative (`etc/ssh/...`, no leading `/`) — that's why the single-file extraction omits the leading slash.

**T10 — Documentation**

```bash
man 5 passwd                      # 1. section 5 (file formats)
man -k "partition table"          # 2. apropos — fdisk, sfdisk, cfdisk, parted, partprobe...
man journalctl | grep -A3 '\-b'   # 3. -b / --boot, from man 1 journalctl
ls /usr/share/doc/chrony/         # 4. e.g. /usr/share/doc/chrony/README
info coreutils                    # 5. top node "GNU Coreutils"
man 5 fstab                       # 6. describes /etc/fstab; 6th field = fsck pass order
```

Write the six answers into `/root/docs_answers.txt`. `man -k` is `apropos`; if it returns nothing, run `sudo mandb`. The sixth fstab field is the `fs_passno` — `0` = never check, `1` = root filesystem, `2` = other filesystems.

---

### Section 3 — Users, Groups & Permissions

**T11 — Skeleton and home relocation**

```bash
echo "Welcome to the EX200 lab" | sudo tee /etc/skel/lab_welcome.txt
sudo mkdir -p /etc/skel/projects

sudo groupadd -g 7000 research
sudo useradd -u 3100 -g research emma
sudo useradd -u 3101 -g research noah
ls -a /home/emma /home/noah          # skeleton copied at creation time

sudo useradd -u 3102 -g research -d /opt/oscar -m oscar
ls -a /opt/oscar

sudo usermod -d /srv/homes/noah -m noah
getent passwd noah
sudo restorecon -Rv /srv/homes/noah  # relocated homes need relabeling
```

`-m` with `-d` **moves** the existing contents. Skeleton files are copied only at creation — editing `/etc/skel` later does not retroactively update existing users.

**T12 — sudo Defaults**

```bash
sudo visudo -f /etc/sudoers.d/lab3_defaults
```

```
Defaults:%research    timestamp_timeout=0
Defaults              logfile="/var/log/sudo_lab.log"
Defaults              secure_path="/usr/local/lab/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

%research   ALL=(ALL) ALL
```

```bash
sudo visudo -cf /etc/sudoers.d/lab3_defaults
sudo -l -U emma
```

Editing with `visudo -f` is the safe path — it syntax-checks before saving. `Defaults:%group` scopes a default to a group; `timestamp_timeout=0` forces a password on every invocation.

**T13 — ACL mask**

```bash
sudo mkdir -p /srv/shared/data
sudo chown emma:research /srv/shared/data
sudo chmod 2770 /srv/shared/data

sudo setfacl -m u:noah:rwx -m g:wheel:r-x /srv/shared/data
sudo setfacl -d -m u:noah:rwx -d -m g:wheel:r-x /srv/shared/data

sudo setfacl -m m::r-x /srv/shared/data
getfacl /srv/shared/data > /root/acl_effective.txt
```

`getfacl` now shows `user:noah:rwx  #effective:r-x`. The mask is the **ceiling** on every named user, named group, and the owning group — effective permission is the ACL entry ANDed with the mask, so `noah`'s write bit is masked off without his entry changing.

```bash
sudo -u emma touch /srv/shared/data/test.txt
getfacl /srv/shared/data/test.txt      # inherited from the default ACL
sudo setfacl -m m::rwx /srv/shared/data
getfacl /srv/shared/data               # noah effective rwx again
```

**T14 — cp vs mv contexts**

```bash
echo "Context Test" > /root/site_index.html
cp /root/site_index.html /root/site_index2.html
cp /root/site_index.html /root/site_index3.html

ls -Z /root/site_index.html      > /root/context_report.txt

sudo cp /root/site_index.html /var/www/html/copied.html
ls -Z /var/www/html/copied.html  >> /root/context_report.txt   # httpd_sys_content_t ✔

sudo mv /root/site_index2.html /var/www/html/moved.html
ls -Z /var/www/html/moved.html   >> /root/context_report.txt   # admin_home_t ✘

sudo restorecon -v /var/www/html/moved.html

sudo cp --preserve=context /root/site_index3.html /var/www/html/preserved.html
ls -Z /var/www/html/preserved.html >> /root/context_report.txt
```

**`cp` creates a new inode**, so it inherits the *destination directory's* default context — correct for httpd. **`mv` preserves the inode and its label**, dragging `admin_home_t` along — httpd is denied. This is the single most common SELinux trap on the exam. `restorecon` reapplies the policy default; `chcon` sets a label that a relabel will later undo.

---

### Section 4 — Networking

**T15 — Two profiles**

```bash
nmcli con show                              # find the device name, e.g. enp1s0
sudo nmcli con add type ethernet ifname enp1s0 con-name lab3-static \
  ipv4.method manual ipv4.addresses 172.16.40.21/24 ipv4.gateway 172.16.40.1 \
  ipv4.dns "172.16.40.1 1.1.1.1" \
  ipv6.method manual ipv6.addresses fd10::21/64 \
  connection.autoconnect yes
sudo nmcli con add type ethernet ifname enp1s0 con-name lab3-dhcp \
  ipv4.method auto ipv6.method auto connection.autoconnect no

ip -4 addr show enp1s0
ip -6 addr show enp1s0
ping6 -c2 fd10::22                          # reach foxtrot over IPv6

sudo nmcli con up lab3-dhcp        # switch
sudo nmcli con up lab3-static      # switch back
sudo hostnamectl set-hostname echo.ex200.net

printf '172.16.40.21 echo.ex200.net echo\n172.16.40.22 foxtrot.ex200.net foxtrot\n' \
  | sudo tee -a /etc/hosts

cat > /root/resolution.txt <<'EOF'
/etc/nsswitch.conf controls lookup order.
The applicable line is:  hosts: files dns myhostname
"files" = /etc/hosts is consulted before DNS.
EOF
ping -c2 foxtrot
```

Bringing one profile up on a shared interface automatically brings the other down — only one connection can be active per device.

**T16 — Port forwarding**

```bash
sudo dnf install -y httpd
echo "echo web" | sudo tee /var/www/html/index.html
sudo systemctl enable --now httpd

sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-forward-port=port=8888:proto=tcp:toport=80
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

# From foxtrot:
curl http://echo.ex200.net:8888
```

Masquerade is required when forwarding to a *different* host (`:toaddr=`); for a same-host forward it is harmless but the task asks for it explicitly. Forward ports appear under `forward-ports:` in `--list-all`.

---

### Section 5 — Software Management

**T17 — Repos and queries**

```bash
sudo mkdir -p /mnt/dvd
echo '/dev/sr0  /mnt/dvd  iso9660  ro,nofail  0 0' | sudo tee -a /etc/fstab
sudo mount -a

sudo rpm --import /mnt/dvd/RPM-GPG-KEY-redhat-release

sudo tee /etc/yum.repos.d/lab3.repo >/dev/null <<'EOF'
[BaseOS]
name=RHEL 10 BaseOS (DVD)
baseurl=file:///mnt/dvd/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///mnt/dvd/RPM-GPG-KEY-redhat-release

[AppStream]
name=RHEL 10 AppStream (DVD)
baseurl=file:///mnt/dvd/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///mnt/dvd/RPM-GPG-KEY-redhat-release
EOF

dnf repolist
dnf provides /usr/bin/semanage   > /root/q1.txt   # policycoreutils-python-utils
rpm -qf /etc/chrony.conf         > /root/q2.txt   # chrony
rpm -ql chrony                   > /root/q3.txt
dnf search "network manager"     > /root/q4.txt
```

`nofail` is what keeps a missing disc from dropping the machine to emergency mode — exactly the Task 1 failure mode. `dnf provides` searches repo metadata (works for uninstalled packages); `rpm -qf` only answers for files already on disk.

**T18 — History rollback**

```bash
sudo dnf install -y tmux
dnf history list | head
# note the ID of the tmux install, e.g. 14
echo 14 > /root/history_id.txt
dnf history info 14
sudo dnf history undo 14 -y
rpm -q tmux                       # not installed
sudo dnf history redo 14 -y
rpm -q tmux
```

`undo` reverses a transaction (removing what it installed); `redo` re-applies it; `rollback <id>` reverts everything *after* that point.

**T19 — RPM operations**

```bash
sudo dnf download --destdir /root/rpms zsh
cd /root/rpms
rpm -qlp zsh-*.rpm      > /root/rpm1.txt      # -p = query the package FILE
rpm -q --scripts -p zsh-*.rpm > /root/rpm2.txt

mkdir -p /root/extracted && cd /root/extracted
rpm2cpio /root/rpms/zsh-*.rpm | cpio -idmv './usr/share/man/man1/zsh.1*'

rpm -K /root/rpms/zsh-*.rpm       # signature check
sudo rpm -ivh /root/rpms/zsh-*.rpm
rpm -V zsh                        # silence = unmodified
```

`-p` makes any `rpm -q` operate on an uninstalled `.rpm` file. `rpm2cpio | cpio -idmv` extracts without installing; `rpm2archive` is the newer equivalent.

---

### Section 6 — Storage

**T20 — fdisk, type codes, and a table backup**

```bash
sudo fdisk /dev/vdb
# g          → new empty GPT label
# n          → part 1, default first sector, +3G      (type defaults to Linux filesystem)
# n          → part 2, default first sector, +2G
# t          → change type; select partition 2
#   L        → list type codes, find "Linux LVM"
#   31       → Linux LVM  (see caveat below)
# p          → print to confirm
# w          → write and exit

sudo partprobe /dev/vdb
lsblk /dev/vdb
sudo fdisk -l /dev/vdb
```

Capture the layout with type GUIDs and PARTUUIDs, and take a restorable backup:

```bash
# sfdisk's dump format shows type= (GUID) and uuid= (PARTUUID) per partition
sudo sfdisk -d /dev/vdb | sudo tee /root/gpt_layout.txt
sudo lsblk -o NAME,SIZE,PARTTYPENAME,PARTUUID /dev/vdb | sudo tee -a /root/gpt_layout.txt

# Restorable backup of the partition table
sudo sfdisk -d /dev/vdb | sudo tee /root/vdb-parttable.bak
echo '# Restore with: sudo sfdisk /dev/vdb < /root/vdb-parttable.bak' \
  | sudo tee -a /root/gpt_layout.txt
```

> **Type codes are version-dependent.** In current util-linux, GPT shortcuts are `20` = Linux filesystem, `19` = Linux swap, `31` = Linux LVM — but these numbers have changed between releases, so **press `L` and read the list** rather than memorizing them. `fdisk` also accepts the full type GUID directly (Linux LVM is `E6D6D379-F507-44C2-A23C-238F2A3DF928`), which never changes.
>
> **Why `fdisk` and not `gdisk`:** `fdisk` is part of `util-linux` and is present on every minimal install. `gdisk` ships in a separate package you would have to install first — a dependency you do not want to discover mid-exam on an offline system. `fdisk` has handled GPT natively for years, so there is nothing `gdisk` gives you here that you need.

**T21 — Shrink an ext4 LV**

```bash
sudo pvcreate /dev/vdb2 /dev/vdc
sudo vgcreate -s 8M vg_ex3 /dev/vdb2 /dev/vdc
sudo lvcreate -L 4G -n lv_shrink vg_ex3
sudo mkfs.ext4 /dev/vg_ex3/lv_shrink
sudo mkdir -p /mnt/shrink
echo "UUID=$(sudo blkid -s UUID -o value /dev/vg_ex3/lv_shrink) /mnt/shrink ext4 defaults 0 0" \
  | sudo tee -a /etc/fstab
sudo mount -a

sudo dd if=/dev/urandom of=/mnt/shrink/testfile bs=1M count=50
sudo sha256sum /mnt/shrink/testfile | sudo tee /root/checksum_before.txt

# --- the shrink ---
sudo umount /mnt/shrink                       # ext4 CANNOT shrink while mounted
sudo e2fsck -f /dev/vg_ex3/lv_shrink
sudo lvreduce -L 2G -r /dev/vg_ex3/lv_shrink  # -r drives resize2fs via fsadm
sudo mount -a

sudo sha256sum -c /root/checksum_before.txt
lvs vg_ex3

cat > /root/shrink_notes.txt <<'EOF'
XFS cannot be shrunk at all - the filesystem supports online growth only.
Reducing an XFS-backed LV would destroy the filesystem, so the only route
is backup, lvreduce, mkfs.xfs, restore.
EOF
```

Always shrink the **filesystem before** the volume. `-r` does both in the right order; doing `lvreduce` alone on a full-size filesystem silently truncates it.

**T22 — Replace swap**

```bash
swapon --show > /root/swap_before.txt
free -h >> /root/swap_before.txt

sudo fdisk /dev/vdb     # g (if the disk is blank) → n → +1G → t → L → 19 (Linux swap) → w
sudo partprobe /dev/vdb
sudo mkswap -L EX3SWAP /dev/vdb1
echo 'LABEL=EX3SWAP none swap defaults,pri=5 0 0' | sudo tee -a /etc/fstab
sudo swapon -a
swapon --show                            # NAME, LABEL, PRIO 5

# --- Remove the original (LVM) swap ---
sudo cp /etc/fstab /etc/fstab.bak        # ALWAYS, before touching fstab
sudo swapoff /dev/mapper/rhel-swap
sudo vi /etc/fstab                       # delete the old swap line by hand
```

Edit `/etc/fstab` **by hand**. A scripted delete is where this task bites people — the LABEL line you just added also contains the word `swap`, so a naive `sed '/swap/d'` removes both and you lose the work. If you insist on scripting it, guard the new entry and diff before rebooting:

```bash
sudo sed -i '/[[:space:]]swap[[:space:]]/{/EX3SWAP/!d}' /etc/fstab
diff /etc/fstab.bak /etc/fstab           # confirm EXACTLY one line went away
```

```bash
sudo lvremove -y /dev/rhel/swap          # optional: reclaim the extents
sudo mount -a && sudo swapon -a          # PROVE fstab is valid before rebooting
sudo reboot

swapon --show > /root/swap_after.txt
```

`mount -a` before you reboot is the habit worth building — a bad fstab edit here is precisely the Task 1 failure, and you already know how expensive that recovery is. Removing the swap *entry* is what makes it permanent; `swapoff` alone reverts at boot.

**T23 — Mount options and remount**

```bash
sudo fdisk /dev/vdb                      # n → +2G → (type defaults to Linux filesystem) → w
sudo partprobe /dev/vdb
sudo mkfs.xfs /dev/vdb2
sudo mkdir -p /data/vault
echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb2) /data/vault xfs defaults,noexec,nosuid,nodev 0 0" \
  | sudo tee -a /etc/fstab
sudo mount -a

sudo cp /bin/ls /data/vault/
/data/vault/ls 2> /root/noexec_proof.txt     # "Permission denied"

sudo mount -o remount,ro /data/vault
sudo touch /data/vault/x 2>> /root/noexec_proof.txt   # "Read-only file system"
sudo mount -o remount,rw /data/vault
findmnt /data/vault > /root/mount_opts.txt
```

`mount -o remount` changes options on a live mount without unmounting — useful when a filesystem is busy.

**T24 — Bind mount**

```bash
sudo mkdir -p /srv/appdata /opt/app/data
echo "bind payload" | sudo tee /srv/appdata/payload.txt
echo '/srv/appdata  /opt/app/data  none  bind  0 0' | sudo tee -a /etc/fstab
sudo mount -a
ls /opt/app/data/payload.txt
findmnt /opt/app/data
sudo reboot
```

Filesystem type is `none` and the option is `bind`. `mount --bind /srv/appdata /opt/app/data` is the ad-hoc equivalent.

---

### Section 7 — NFS & AutoFS

**T25 — NFS server with a diagnostic**

```bash
sudo dnf install -y nfs-utils
sudo mkdir -p /export/team
sudo chown nobody:nobody /export/team
sudo chmod 2775 /export/team

echo '/export/team 172.16.40.0/24(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports
sudo systemctl enable --now nfs-server
sudo firewall-cmd --permanent --add-service={nfs,mountd,rpc-bind}
sudo firewall-cmd --reload
sudo exportfs -rav
sudo exportfs -v
```

Now the diagnostic step — introduce the space:

```bash
# WRONG:  /export/team 172.16.40.0/24 (rw,sync,no_subtree_check)
sudo exportfs -rav
sudo exportfs -v > /root/exports_typo.txt
```

With a space, `172.16.40.0/24` becomes a client with **default** options (`ro,root_squash`) and the parenthesised list becomes a *second* client entry matching everything — so the share silently goes read-only for the intended clients and world-readable. Remove the space and re-export.

**T26 — AutoFS indirect map**

```bash
# echo
sudo dnf install -y autofs
echo '/net/team  /etc/auto.team  --timeout=45' | sudo tee /etc/auto.master.d/team.autofs
echo '*  -fstype=nfs4,rw  foxtrot.ex200.net:/export/&' | sudo tee /etc/auto.team
sudo systemctl enable --now autofs

ls /net/team/team          # key "team" → foxtrot:/export/team
findmnt | grep team
sleep 60 && findmnt | grep team    # gone
```

With the wildcard map above, the mount key is the directory name requested under `/net/team`. A single fixed share can equally use a direct map (`/-  /etc/auto.direct` with `/net/team  -rw  foxtrot:/export/team`).

---

### Section 8 — Services, Logging, Time & Scheduling

**T27 — journalctl filtering**

```bash
journalctl -b -u sshd                                   > /root/j1.txt
journalctl --since "09:00" --until "12:00"              > /root/j2.txt
journalctl --since yesterday -p err                     > /root/j3.txt
journalctl _COMM=sudo                                   > /root/j4.txt
journalctl --disk-usage                                 > /root/j5.txt

sudo journalctl --vacuum-size=200M
sudo sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=200M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

`-u` matches the systemd unit; `_COMM=` matches the process name regardless of unit — different tools for different questions. Time strings accept `yesterday`, `-1h`, and `"YYYY-MM-DD HH:MM:SS"`.

**T28 — Persistent sysctl**

```bash
sudo tee /etc/sysctl.d/99-lab3.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
vm.swappiness = 20
kernel.pid_max = 65536
EOF

sudo sysctl -p /etc/sysctl.d/99-lab3.conf     # or: sudo sysctl --system
sysctl net.ipv4.ip_forward vm.swappiness kernel.pid_max > /root/sysctl_verify.txt
sudo reboot
```

`sysctl --system` reloads every file in the drop-in directories in order; `-p <file>` loads just one. Files in `/etc/sysctl.d/` are read in lexical order, which is why the `99-` prefix wins.

**T29 — at, at.allow, cron.d**

```bash
sudo systemctl enable --now atd
echo 'echo "at job ran" >> /var/log/at3.log' | at now + 10 minutes
atq
at -c <jobnum> > /root/at_job.txt
atrm <jobnum>
atq                                        # empty

echo emma | sudo tee /etc/at.allow         # allow-list: only emma (plus root)
sudo chmod 600 /etc/at.allow

sudo tee /etc/cron.d/labreport >/dev/null <<'EOF'
45 5 * * 1,4 emma /usr/local/bin/labreport.sh
EOF

cat > /root/crond_note.txt <<'EOF'
A /etc/cron.d file has SIX time/command fields plus a USER field:
  min hr dom mon dow  USER  command
A user crontab (crontab -e) has no user field - it always runs as its owner.
EOF
```

If `/etc/at.allow` exists, only users listed in it may use `at` and `/etc/at.deny` is ignored entirely. `cron.allow`/`cron.deny` work the same way for cron.

**T30 — Chrony**

```bash
# foxtrot (server)
sudo sed -i 's/^pool /#pool /; s/^server /#server /' /etc/chrony.conf
echo 'allow 172.16.40.0/24' | sudo tee -a /etc/chrony.conf
echo 'local stratum 10'     | sudo tee -a /etc/chrony.conf
sudo systemctl enable --now chronyd && sudo systemctl restart chronyd
sudo firewall-cmd --permanent --add-service=ntp && sudo firewall-cmd --reload

# echo (client)
sudo sed -i 's/^pool /#pool /; s/^server /#server /' /etc/chrony.conf
echo 'server foxtrot.ex200.net iburst' | sudo tee -a /etc/chrony.conf
sudo systemctl restart chronyd
chronyc sources -v                      # foxtrot marked ^* once selected

sudo timedatectl set-local-rtc 0
sudo timedatectl set-timezone America/Denver
timedatectl > /root/time_status.txt
```

`local stratum 10` lets the server serve time even when it has no upstream source — necessary in an offline lab.

---

### Section 9 — Scripting

**T31 — diskwatch.sh**

```bash
sudo tee /usr/local/bin/diskwatch.sh >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

usage() { echo "Usage: $0 <mountpoint>" >&2; exit 2; }

[[ $# -eq 1 ]] || usage
target="$1"

if ! findmnt -n "$target" >/dev/null 2>&1; then
    echo "Not mounted: $target" >&2
    exit 3
fi

pct=$(df --output=pcent "$target" | tail -1 | tr -d ' %')

if (( pct >= 80 )); then
    echo "CRITICAL: $target at ${pct}%"
    exit 1
fi

echo "OK: $target at ${pct}%"
exit 0
EOF
sudo chmod 755 /usr/local/bin/diskwatch.sh

{
  diskwatch.sh          ; echo "no-arg exit: $?"
  diskwatch.sh /nope    ; echo "bad-path exit: $?"
  diskwatch.sh /        ; echo "root exit: $?"
  diskwatch.sh /boot    ; echo "boot exit: $?"
} > /root/diskwatch_tests.txt 2>&1
```

With `set -e` a non-zero command aborts the script, so the `if ! findmnt` guard must wrap the test — a bare `findmnt` would kill the script before your custom exit code ran.

**T32 — userreport.sh**

```bash
sudo tee /usr/local/bin/userreport.sh >/dev/null <<'EOF'
#!/bin/bash
OUT=/var/log/userreport.txt

{
  echo "=== User Report: $(date) ==="

  echo -n "Accounts with valid login shells: "
  grep -vcE '(/sbin/nologin|/bin/false)$' /etc/passwd

  echo "Top 5 UIDs:"
  sort -t: -k3 -n -r /etc/passwd | head -5 | cut -d: -f1,3

  echo "Groups with no members:"
  awk -F: '$4 == "" {print $1}' /etc/group

  echo -n "Locked accounts: "
  passwd -Sa 2>/dev/null | awk '$2 == "L"' | wc -l
} > "$OUT"
EOF
sudo chmod +x /usr/local/bin/userreport.sh
sudo /usr/local/bin/userreport.sh
cat /var/log/userreport.txt
```

Note the "no members" check reads field 4 of `/etc/group` — users whose *primary* group it is are not listed there, which is the expected behavior for this report.

---

### Section 10 — SELinux

**T33 — Diagnose from scratch**

```bash
sudo systemctl start httpd            # fails
systemctl status httpd                > /root/selinux_diag.txt
sudo journalctl -xeu httpd           >> /root/selinux_diag.txt
sudo ausearch -m AVC -ts recent      >> /root/selinux_diag.txt
sudo ausearch -m AVC -ts recent | audit2why >> /root/selinux_diag.txt
sudo sealert -a /var/log/audit/audit.log | head -50 >> /root/selinux_diag.txt
```

Two distinct problems, each with its own correct fix:

```bash
# 1. Port 8404 is not a labeled http port  → port label
sudo semanage port -a -t http_port_t -p tcp 8404
sudo semanage port -l | grep http_port_t

# 2. /srv/intranet is default_t, not web content  → file context
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/intranet(/.*)?'
sudo restorecon -Rv /srv/intranet

sudo systemctl enable --now httpd
curl http://localhost:8404/            # Echo Intranet OK
sudo ausearch -m AVC -ts recent        # no new denials
sudo reboot
```

The lesson is matching fix to denial *type*: a `name_bind` denial on a port needs `semanage port`; a `read`/`getattr` denial on a file needs `semanage fcontext` + `restorecon`; a denial the policy already anticipates needs `setsebool -P`. `audit2why` tells you which of those three you're looking at.

**T34 — Local policy module**

```bash
sudo getenforce                        # Enforcing
# Generate a denial httpd genuinely lacks permission for:
sudo cp /root/anaconda-ks.cfg /srv/intranet/secret.txt   # arrives as admin_home_t
curl http://localhost:8404/secret.txt  # 403
sudo ausearch -m AVC -ts recent | audit2why

sudo ausearch -m AVC -ts recent | audit2allow -M labhttpd
cat labhttpd.te                        # ALWAYS read before installing
sudo semodule -i labhttpd.pp
sudo semodule -l | grep labhttpd
curl http://localhost:8404/secret.txt  # now succeeds

cat > /root/policy_module.txt <<'EOF'
A custom module grants a new permission permanently and system-wide.
Here the file was simply mislabeled - restorecon would have fixed it
without weakening policy. Prefer, in order:
  1. restorecon / semanage fcontext  (wrong label)
  2. setsebool -P                    (policy already supports the case)
  3. audit2allow module              (only when nothing else covers it)
EOF
```

> **Leave the module installed.** Task step 5 asks you to confirm it appears in `semodule -l`, and the verification script checks for exactly that — removing it will fail the T34 check. If you want a clean policy afterwards, run `sudo semodule -r labhttpd` **after** you have scored the exam, not before.

Never install an `audit2allow` module without reading the generated `.te` — it grants exactly what was denied, including anything an attacker triggered.

---

### Section 11 — Containers

**T35 — skopeo, login, AutoUpdate Quadlet**

```bash
# as root
sudo dnf install -y podman skopeo
sudo loginctl enable-linger emma
```

```bash
# as emma
skopeo inspect docker://registry.access.redhat.com/ubi10/ubi:latest > ~/skopeo_inspect.txt
skopeo list-tags docker://registry.access.redhat.com/ubi10/ubi     > ~/skopeo_tags.txt

podman login registry.redhat.io
echo "${XDG_RUNTIME_DIR}/containers/auth.json" > ~/auth_path.txt

podman volume create emma-site
podman run --rm -v emma-site:/data registry.access.redhat.com/ubi10/ubi \
  sh -c 'echo "Echo Container OK" > /data/index.html'

mkdir -p ~/.config/containers/systemd
cat > ~/.config/containers/systemd/emma-site.container <<'EOF'
[Unit]
Description=Emma Site
Wants=network-online.target
After=network-online.target

[Container]
Image=registry.access.redhat.com/ubi10/httpd-24
ContainerName=emma_site
PublishPort=9191:8080
Volume=emma-site:/var/www/html:Z
Environment=LAB_ENV=exam3
AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user start emma-site.service
curl http://localhost:9191/

systemctl --user enable --now podman-auto-update.timer
```

Rootless credentials live in `${XDG_RUNTIME_DIR}/containers/auth.json` (root's are in `/run/containers/0/auth.json`). `AutoUpdate=registry` plus `podman-auto-update.timer` is what makes the container refresh itself. Quadlet files are **not** enabled with `systemctl --user enable` — the generator creates the unit from the `[Install]` section at `daemon-reload`; you `start` it.

---

## 📚 What This Exam Adds Over Exams 1 & 2

| Area | Exams 1 & 2 | Exam 3 |
| ---- | ----------- | ------ |
| Boot recovery | Reset a forgotten password | **Repair an unbootable system** with the password also unknown |
| Boot targets | `set-default` | **One-shot GRUB target** + `grubby` for kernel args |
| Services | Start/enable working units | **Diagnose a failing unit**; **drop-in overrides** |
| Essential tools | Never tested | **Redirection, grep/regex, find, tar/bzip2, man/info** |
| sudo | Aliases, NOPASSWD | **`Defaults`**: timestamps, logfile, secure_path |
| ACLs | Set entries | **Mask semantics** + effective permissions |
| SELinux contexts | Set and restore | **`cp` vs `mv`** inheritance, `--preserve=context` |
| SELinux fixes | Told what to fix | **Diagnose unaided**; `audit2why`, `sealert`, custom module |
| Networking | One profile | **Two profiles**, switching, `nsswitch` order |
| Firewall | Services, ports, zones | **Port forwarding + masquerade** |
| Packages | Install/remove/verify | **`dnf history` undo/redo**, `rpm2cpio`, `-qlp`, `--scripts` |
| Partitioning | `fdisk` interactive, `parted -s` | **Type codes** (`t`/`L`), **`sfdisk -d`** dump + restorable backup |
| LVM | Extend | **Shrink ext4** (and why XFS can't) |
| Swap | Add partition / file | **Replace and remove** cleanly |
| Mounts | fstab by UUID/LABEL | **Live remount ro/rw**, `noexec` proof, **bind mounts** |
| NFS | Configure | **Diagnose a malformed export** |
| Logging | Persistent journal | **Time/field filtering**, vacuum, size caps |
| Kernel tunables | Via tuned | **`/etc/sysctl.d/` drop-ins** |
| Scheduling | at, cron, timers | **`at.allow`**, `at -c`, **`/etc/cron.d` user field** |
| Scripting | if/case/for/while | **strict mode + meaningful exit codes**, text processing |
| Containers | podman + Quadlet | **skopeo**, **`podman login`**, **`AutoUpdate=registry`** |

---

## 🎯 Five-Week Run-Up (Sep 9 → mid-October 2026)

The delayed exam date turns the biggest weakness in this practice set — that Exams 1 and 2 were worked *with their answers visible* — into something you now have time to fix. Use it:

| Week | Dates | Focus |
| ---- | ----- | ----- |
| 1 | Sep 9–15 | Build `echo`/`foxtrot`. Run **Exam 3 cold and timed**. Expect a low score — that is the diagnostic, not a failure |
| 2 | Sep 16–22 | Re-run **Exams 1 and 2 cold**, with the inline solutions covered or scrolled past. This is the recall-vs-recognition fix |
| 3 | Sep 23–29 | Re-run **Exam 3**; drill only what failed twice across all three |
| 4 | Sep 30 – Oct 6 | All three back-to-back over a weekend. Target **30/35 each**. Book the real exam once you hit it |
| 5 | Oct 7–14 | Light review only. Weak-area drills, no new material. Take EX200 |

**If a week gets eaten** (travel, work, family), collapse to this priority order:

1. **Tasks 1, 4, 33** — recovery and diagnosis. Highest-value, least-practiced, and what turns a bad exam day around.
2. **Section 2 (Tasks 6–10)** — six listed objectives you have never drilled. Fast to complete, cheap to fix.
3. **Tasks 14, 21, 22, 24** — the storage and SELinux traps most likely to cost you a whole task.
4. Everything else as reinforcement.

---

*Practice exam #3 created 2026-09-09. Companion to `[[RHCSA Practice Exam 1 - RHEL 10]]` and `[[RHCSA Practice Exam 2 - RHEL 10]]`. Lab build instructions extend `[[RHCSA Exam Lab Setup]]` Phase 0.*
