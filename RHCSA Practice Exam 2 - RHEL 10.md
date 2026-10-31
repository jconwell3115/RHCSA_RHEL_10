---
title: RHCSA Practice Exam 2 - RHEL 10
tags: [certifications, rhcsa, rhel10, practice, linux]
created: 2026-07-08
restructured: 2026-09-09 - answer key moved to bottom for cold re-runs
note: Answer key is at the BOTTOM of this file. Do not scroll past the Grading Checklist during a timed run.
---
# 🧪 RHCSA Practice Exam 2 — RHEL 10 (EX200)

> **Format:** Performance-based | **Time budget:** 3 hours | **Pass Score:** ~70% (25 / 35)
> All configurations **must persist after reboot** without intervention.
> You may use `man`, `info`, and `/usr/share/doc` — no internet access on exam day.
> This exam re-tests the same objectives as Exam #1 using different scenarios, values, and services.

> **⏱️ Budget is 3 hours, not 2.5.** 35 tasks at 2.5 hrs works out to ~4.3 min/task, which is not achievable. Don't read a timer overrun as "not ready" — the real EX200 presents far fewer, larger tasks. Confirm the real exam's current duration on Red Hat's objectives page.

> **📌 Answer key is at the end of this file, not under each task.** Solutions and the command quick-reference were moved on 2026-09-09 so this exam can be re-run cold.

---

## 🖥️ Lab Environment Setup

### Required Virtual Machines

| VM                 | vCPU | RAM  | Primary Disk      | Extra Disks                                            |
| ------------------ | ---- | ---- | ----------------- | ------------------------------------------------------ |
| `rhel10-charlie` | 2    | 2 GB | 20 GB`/dev/vda` | 8 GB`/dev/vdb`, 6 GB `/dev/vdc`, 4 GB `/dev/vdd` |
| `rhel10-delta`   | 2    | 2 GB | 20 GB`/dev/vda` | 8 GB`/dev/vdb`                                       |

### Build and seed

Build and seed both VMs with [README.md](README.md): Phase 1 for `rhcsa-net2`, Phase 2 for `add-disk.sh`, Phase 2.5 for the DVD ISO, and Phase 4 for the VMs and the `exam2-ready` snapshot.

### Repo Setup (Pre-Task — Simulates Exam Environment)

- Attach the RHEL 10 DVD ISO to **both** VMs. It appears as `/dev/sr0` in each (see README Phase 4.6b)
- Don't register with `subscription-manager`. The real exam is offline, so the DVD is the only package source
- Don't create the repo files yet. That's Task 13
- Delta needs packages too (Task 2 GUI group, Task 21 `nfs-utils`), so it gets the same media

---

## 📋 Exam Instructions

1. All tasks must be completed on the correct host (`charlie` or `delta`)
2. All configurations must survive a `reboot` — test this for critical tasks
3. Work methodically; a wrong `fstab` entry can break boot
4. Do NOT delete pre-existing users, groups, files, or services unless explicitly told to
5. If a task depends on a previous one and you cannot complete the previous, **still attempt the current one** on a plausible substitute
6. **Do not scroll to the answer key.** If you're stuck, use `man` — that's the skill being tested
7. **Configure repositories first.** Nothing installs until Task 13 is done, and Tasks 2, 6, 14, 15, 17, 21 and later all need packages. Do Task 13 on charlie before anything else, then set up the same repos on delta. On the real EX200, do the repo task first too, whatever its number

---

## 🚀 PRACTICE EXAM #2 — 35 TASKS

---

### SECTION 1: System Recovery & Boot Management

---

**Task 1 — Emergency Recovery via GRUB Kernel Argument** *(charlie)*

> Objective: Interrupt the boot process in order to gain access to a system

The root password on `rhel10-charlie` is unknown. Use the **`init=/bin/bash`** method to recover:

1. Interrupt GRUB, edit the kernel line, replace `ro` with `rw` and append `init=/bin/bash`
2. Boot to a raw bash shell
3. Reset the root password to `Ex200Pass!`
4. Ensure SELinux will relabel on next boot
5. Reboot cleanly

> **Lab note:** Every lab VM's `linux` line has `console=ttyS0,115200 console=tty0`, in that order. If you edit that line in GRUB, confirm both are there with `console=tty0` last. With `console=ttyS0,115200` last, the shell opens on serial and the graphical console looks hung. If that happens, run `sudo virsh console <vm>` on the host.

---

**Task 2 — Change Default Target from Rescue to Graphical** *(delta)*

> Objective: Boot systems into different targets manually

`rhel10-delta` is booting into `rescue.target`. Change the default target to `graphical.target` and reboot. Verify with `systemctl get-default` and confirm `runlevel` output shows `5`.

Then install the required package group if the GUI is not present.

---

**Task 3 — Bootloader: Disable Quiet Boot and Add Kernel Argument** *(charlie)*

> Objective: Modify the system bootloader

On `charlie`, edit GRUB with the following persistent changes:

- Remove `rhgb` and `quiet` from `GRUB_CMDLINE_LINUX`
- Add `audit=1` and `net.ifnames=0`
- Set `GRUB_TIMEOUT=5`

Regenerate GRUB using `grub2-mkconfig` **and** rebuild the initramfs with `dracut -f`. Reboot and verify with `cat /proc/cmdline`.

---

### SECTION 2: Networking & Hostname

---

**Task 4 — Configure Networking with `nmcli` + Custom DNS** *(both nodes)*

> Objective: Configure IPv4 and IPv6 addresses, Configure hostname resolution

| Host    | Hostname              | IPv4               | IPv6            | Gateway        | DNS                     |
| ------- | --------------------- | ------------------ | --------------- | -------------- | ----------------------- |
| charlie | `charlie.ex200.lab` | `10.20.30.11/24` | `fd42::11/64` | `10.20.30.1` | `10.20.30.1, 1.1.1.1` |
| delta   | `delta.ex200.lab`   | `10.20.30.12/24` | `fd42::12/64` | `10.20.30.1` | `10.20.30.1, 1.1.1.1` |

- Set the connection to autoconnect at boot
- Add a **connection alias** named `lab-static` on both nodes
- Add both hosts to `/etc/hosts` on each node
- Verify both hosts can ping each other by short hostname (`charlie`, `delta`)

---

**Task 5 — Firewalld: Custom Zone with Rich Rules** *(charlie)*

> Objective: Restrict network access using firewall-cmd/firewalld

On `charlie`:

1. Create a **new permanent zone** called `labzone`
2. Assign the `lab-static` connection to `labzone`
3. In `labzone`, permanently allow:
   - `ssh`, `https`, `dns`
   - TCP port range `9000-9010`
4. Add a **rich rule** to `labzone` that drops all traffic from `10.20.30.100` for `60s`
5. Set `labzone` as the **default zone**
6. Reload and verify with `firewall-cmd --list-all --zone=labzone`

---

### SECTION 3: Users, Groups & Permissions

---

**Task 6 — Users and Groups with Custom Home & Shell** *(charlie)*

> Objective: Create, delete, and modify local user accounts and groups

    Groups:
      ops        GID: 6000
      qateam     GID: 6001
      auditors   GID: 6002  /etc/

    Users:
      emma    UID: 2100  primary: ops       supplementary: qateam        home: /srv/users/emma
      frank   UID: 2101  primary: qateam    supplementary: auditors      shell: /bin/zsh (install zsh)
      gina    UID: 2102  primary: ops                                     comment: "Gina — DBA"
      henry   UID: 2103  primary: auditors  no interactive shell (nologin)

Verify home directories exist, permissions are `700`, and use `getent` to confirm group memberships.

---

**Task 7 — Password Aging via `chage` + PAM `pwquality`** *(charlie)*

> Objective: Change passwords and adjust password aging for local user accounts

- Set the password for all Task 6 users to `Init!Pass2026`
- `emma`: min 3 days, max 45 days, warn 7 days, inactive 14 days
- `frank`: password must be changed on next login, account locks 5 days after expiry
- `gina`: account expires **2027-01-01**
- Configure `/etc/security/pwquality.conf`:
  - `minlen = 12`
  - `dcredit = -1` (at least 1 digit)
  - `ucredit = -1` (at least 1 uppercase)
  - `ocredit = -1` (at least 1 special char)
- Test the policy by trying to set a bad password f:or `gina`

---

**Task 8 — Sudo with User Aliases and NOPASSWD Command Alias** *(charlie)*

> Objective: Configure privileged access

Create `/etc/sudoers.d/lab_sudo`:

- User_Alias `OPSTEAM = emma, gina`
- User_Alias `QAUSERS = frank`
- Cmnd_Alias `NETADMIN = /usr/bin/nmcli, /usr/sbin/ip, /usr/sbin/ss`
- Cmnd_Alias `SVCMGMT = /usr/bin/systemctl status *, /usr/bin/systemctl restart httpd`
- `OPSTEAM` may run `NETADMIN` **without** password
- `QAUSERS` may run `SVCMGMT` **with** password
- The `auditors` group may run `/usr/bin/cat /var/log/*` only

Validate with `visudo -cf /etc/sudoers.d/lab_sudo` and `sudo -l -U emma`.

---

**Task 9 — ACLs on a Shared Project Directory** *(charlie)*

> Objective: List, set, and change standard ugo/rwx permissions (extended via ACLs)

Create `/srv/project/phoenix`:

- Owned by `gina:ops`, mode `2770` (SGID)
- Grant `frank` **rwx** via ACL (default + access ACL)
- Grant the `auditors` group **read-only** access via ACL (default + access ACL)
- Deny `henry` all access with an ACL entry
- Verify with `getfacl /srv/project/phoenix`
- Have `gina` create a file inside and confirm `frank` can edit it and `henry` cannot read it

---

**Task 10 — Umask Per-Group and Symlinks** *(both nodes)*

> Objective: Manage default file permissions, Create hard and soft links

On `charlie`:

- Set the default `umask` for members of `ops` to `0027` (group readable, world excluded)
- Leave all other users at the distribution default
- Do this via a drop-in file in `/etc/profile.d/`

On `delta`:

- Create `/opt/data/original.txt` with content `"exam data"`
- Create a **hard link** `/opt/data/hardlink.txt`
- Create a **symbolic link** `/root/softlink.txt` → `/opt/data/original.txt`
- Delete `/opt/data/original.txt` and demonstrate which link still works
- Explain the inode difference (add a comment in `/root/link_notes.txt`)

---

### SECTION 4: SSH & Remote Access

---

**Task 11 — SSH Key Auth + Disable Password Auth for a Specific User** *(charlie ↔ delta)*

> Objective: Configure key-based authentication for SSH

1. As `root` on `charlie`, generate an **ecdsa-sha2-nistp521** key (no passphrase)
2. Copy the key to `root@delta` using `ssh-copy-id`
3. Create `emma` on `delta` (same UID) and set up key auth from `emma@charlie` → `emma@delta` using an **ed25519** key with passphrase `Lab#2026`
4. On `delta`, configure `sshd_config` so:
   - `PermitRootLogin` = `prohibit-password`
   - `PasswordAuthentication no` **for user `emma` only** (use a `Match User emma` block)
   - `AllowUsers root emma frank`
5. Reload `sshd` and validate with `sshd -t`

---

**Task 12 — Secure File Transfer with Bandwidth Limit + Checksums** *(charlie ↔ delta)*

> Objective: Securely transfer files between systems

- Use `rsync` over SSH from `charlie` to `delta`, syncing `/etc/skel/` to `/tmp/skel_backup/`:
  - Preserve permissions, ownership, timestamps
  - Limit bandwidth to `500 KB/s`
  - Delete extraneous files on destination
- Use `sftp` in **batch mode** with a batch file `/root/sftp_batch.txt` that uploads `/etc/hostname` from charlie to `/tmp/` on delta
- Generate a SHA-256 checksum of `/etc/hostname` on both sides and confirm they match

---

### SECTION 5: Software Management

---

**Task 13 — Configure Two Repositories + GPG Key Import** *(charlie)*

> Objective: Configure access to RPM repositories, install/remove RPM software packages

1. Mount RHEL 10 ISO at `/mnt/rhel10`
2. Create `/etc/yum.repos.d/lab-baseos.repo` and `/etc/yum.repos.d/lab-appstream.repo` (**two separate files** this time)
3. Both must have `gpgcheck=1` — import the GPG key from `/mnt/rhel10/RPM-GPG-KEY-redhat-release`
4. Set `enabled=1` and `metadata_expire=1h`
5. Priority: BaseOS = `10`, AppStream = `20` (`dnf-plugin-priorities` if needed)
6. Confirm with `dnf repolist enabled` and by listing packages available from `lab-baseos` only

---

**Task 14 — Flatpak: Configure Remote + Install App** *(charlie, requires GUI or CLI-only ok)*

> Objective: Configure access to Flatpak repositories, Install and remove Flatpak software packages

1. Install `flatpak` from RPM
2. Add the **Flathub** remote system-wide (not per-user)
3. Search for the app `gedit` (or `org.gnome.gedit`)
4. Install it system-wide
5. List installed Flatpak apps
6. Uninstall it and remove unused runtimes

*(If no internet: document steps in `/root/flatpak_procedure.txt` and skip installation.)*

---

**Task 15 — RPM Verification + Reinstall** *(charlie)*

> Objective: Install and update software packages (RPM level)

1. Install `nano` and record its version
2. Verify the installed package reports no modifications — output should be clean
3. Modify `/etc/nanorc` (add a comment) and verify again — confirm the `5` (checksum) flag appears
4. Restore the config file to its packaged state
5. Query which package owns `/etc/hosts`
6. Query all files installed by the `chrony` package
7. List all installed packages sorted by install date

---

### SECTION 6: Storage — Partitions, LVM & Swap

---

**Task 16 — GPT Partitions with `parted` (Scripted)** *(charlie, `/dev/vdb`)*

> Objective: List, create, and delete partitions on GPT disks

Using **`parted` in non-interactive mode** (not `fdisk`/`gdisk`) on `/dev/vdb`:

1. Create GPT label
2. Create partitions:

   - `vdb1`: 2 GiB — for XFS
   - `vdb2`: 1 GiB — for swap
   - `vdb3`: rest of disk — for LVM (flag: `lvm`)
3. Verify alignment with `parted /dev/vdb align-check optimal 1`
4. Run `partprobe /dev/vdb`

---

**Task 17 — VFAT Filesystem + Mount by Label** *(charlie)*

> Objective: Create, mount, unmount, and use VFAT, ext4, and XFS file systems

- Format `vdb1` as **XFS** with label `charlieXFS`
- Create a small VFAT filesystem on `/dev/vdc` (use partition `vdc1`, size 500 MiB) with label `USBDATA`
- Mount points: `/mnt/charliexfs` and `/mnt/usbdata`
- `/etc/fstab`:
  - `vdb1` mounted by **UUID**
  - `vdc1` mounted by **LABEL**, mount options `noexec,nodev,nosuid`
- Run `mount -a`, then `systemctl daemon-reload`
- Reboot and confirm both are mounted

---

**Task 18 — Swap File (Not Partition) with Priority** *(delta)*

> Objective: Add new partitions and logical volumes, and swap to a system non-destructively

This exam variant uses a **swap file** instead of a swap partition:

1. Create a `1 GiB` file at `/swap/extraswap.img` (use `dd` or `fallocate`)
2. Set permissions to `0600`
3. Format it with `mkswap`
4. Add to `/etc/fstab` with priority `20`, activate with `swapon -a`
5. Verify with `swapon --show` and `free -h`

---

**Task 19 — LVM with Striping and Custom PE Size** *(charlie, `/dev/vdb3` + `/dev/vdd`)*

> Objective: Create/remove PVs, VGs, LVs

1. Initialize `/dev/vdb3` and `/dev/vdd` as physical volumes (whole `vdd`, no partition)
2. Create VG `vg_lab2` with PE size **32 MiB**
3. Create a **striped** LV `lv_stripe` with 2 stripes across both PVs, size `1 GiB`
4. Create a **linear** LV `lv_home2` sized using **80 extents**
5. Format `lv_stripe` as **ext4** and `lv_home2` as **XFS**
6. Mount both persistently at `/mnt/stripe` and `/mnt/home2`
7. Verify with `pvs`, `vgs`, `lvs -a -o+devices`

---

**Task 20 — Reduce a VG, Then Extend an LV** *(charlie)*

> Objective: Extend existing logical volumes; move data non-destructively

1. Migrate all extents off `/dev/vdd`. A plain `pvmove` **will fail here** — work out why, and find the flag that makes it succeed
2. Remove `/dev/vdd` from `vg_lab2` (`vgreduce`)
3. Wipe the LVM signature from `/dev/vdd` (`pvremove`, `wipefs -a`)
4. Extend `lv_home2` to **use all remaining free space** in `vg_lab2` in a **single command** and grow the XFS filesystem online
5. Confirm with `df -h /mnt/home2` and `lvs -a -o+devices` — note what happened to `lv_stripe`'s segment type

---

### SECTION 7: File Systems & NFS

---

**Task 21 — NFSv4 Only, With Kerberos-Ready sec Option** *(delta)*

> Objective: Mount and unmount network file systems using NFS

On `delta` (NFS server):

1. Install `nfs-utils`
2. Disable NFSv3 via `/etc/nfs.conf` — v3 off, v4 and v4.2 on
3. Create `/srv/nfs/projects` and `/srv/nfs/archive`
4. Export them:
   - `/srv/nfs/projects` — read/write to `10.20.30.0/24`, `sync`, `sec=sys`, `no_subtree_check`
   - `/srv/nfs/archive` — read-only to `charlie.ex200.lab`, `sync`, `sec=sys`, `root_squash`
5. Firewall: allow `nfs` service permanently
6. Start/enable `nfs-server`; validate with `exportfs -v` and `showmount -e localhost`

---

**Task 22 — NFS Client with `nofail` and Async Options** *(charlie)*

> Objective: Mount and unmount network file systems using NFS

On `charlie`:

1. Mount points: `/mnt/projects` and `/mnt/archive`
2. Add persistent `/etc/fstab` entries mounting both exports as `nfs4`, with `_netdev` and `nofail`; projects read/write, archive read-only
3. Run `systemctl daemon-reload && mount -a`
4. Create a file in `/mnt/projects` as `root` — expect success
5. Try in `/mnt/archive` — expect read-only failure

---

**Task 23 — AutoFS Indirect Map With Wildcard & Custom Timeout** *(charlie)*

> Objective: Configure autofs

Configure autofs to mount user home directories from `delta:/srv/nfs/homes/<user>` under `/net/homes/<user>`:

1. Install `autofs`
2. Create a master map entry for `/net/homes` with a `60`-second timeout and `--ghost` enabled
3. Create the indirect map file using a wildcard key so any username resolves to its export
4. On `delta`: create `/srv/nfs/homes/emma`, add to exports, reload
5. On `charlie`: `su - emma`, then `ls /net/homes/emma` should trigger the mount
6. Wait 60 seconds idle — mount should auto-unmount

---

**Task 24 — Permission Repair Scenario** *(charlie)*

> Objective: Diagnose and correct file permission problems

The application at `/opt/finance/` has been broken by a bad `chmod`. Fix these issues:

1. `/opt/finance/` — currently `000`; should be `2750`, owned by `gina:ops`
2. `/opt/finance/reports/` — should inherit group `ops` via SGID
3. `/opt/finance/bin/run_report.sh` — needs `0754` and setuid `gina` (mode `4754`)
4. `/opt/finance/private/` — must be `0700`, owned by `gina:gina`
5. Find every SUID binary under `/usr/bin` and save to `/root/suid_list.txt`

---

### SECTION 8: System Services, Logging & Time

---

**Task 25 — Chrony Server + Client** *(both nodes)*

> Objective: Configure time service clients

- On `delta`: configure `chrony` as an **NTP server** for the `10.20.30.0/24` subnet. Enable and start `chronyd`, open firewall for `ntp`.
- On `charlie`: configure `chrony` client to use **delta only** as its time source; remove pool/server defaults.
- Verify with `chronyc sources -v` on charlie — delta should appear with `^*` or `^+`.
- Set timezone: `charlie` → `Europe/London`, `delta` → `Asia/Tokyo`.

---

**Task 26 — Tuned: Create a Fully Custom Profile** *(charlie)*

> Objective: Manage tuning profiles

1. Install and enable `tuned`
2. Create a **new** profile `lab-highio` in `/etc/tuned/profiles/lab-highio/tuned.conf`:
   - Inherit from `throughput-performance`
   - Set `vm.dirty_ratio = 40`
   - Set `vm.swappiness = 10`
   - Set CPU governor to `performance`
3. Activate it
4. Confirm with `tuned-adm active` and `sysctl vm.swappiness`
5. Verify persistence after reboot

---

**Task 27 — Nice, Cgroup Limits, and Killing by Pattern** *(charlie)*

> Objective: Identify CPU/memory intensive processes and kill processes; Adjust process scheduling

1. Launch a CPU-heavy task (`openssl speed -multi 2 &`, or `stress-ng --cpu 2 &`)
2. Launch a task that genuinely consumes RAM — writing into `/dev/shm` (tmpfs) works without extra packages. Watch it with `free -h`, and clean up afterward: the file stays resident in RAM even after the writer exits
3. Identify the top CPU consumer using `ps` with a sort field
4. Change one process's nice value from its default to `19`
5. Launch a process bounded to 20% of a CPU using a transient systemd scope
6. Kill all `stress-ng` and `openssl` processes by matching the full command line
7. Send `SIGHUP` to `sshd` and confirm via the journal that it re-read its config

---

**Task 28 — Journal Forwarding + Log Rotation** *(charlie)*

> Objective: Locate and interpret system log files and journals; Preserve system journals

1. Enable persistent journal storage, max disk size `500M`
2. Configure `journald` to **forward to syslog**
3. Configure `rsyslog` to write `authpriv.*` to `/var/log/secure.lab`, and rotate it weekly keeping 8 weeks via `/etc/logrotate.d/secure.lab`
4. Test: attempt a failed `sudo` as `frank` → confirm the entry appears in both the journal (matched by command name) and `/var/log/secure.lab`
5. Prune journal entries older than 7 days

---

**Task 29 — Systemd Timer with OnCalendar Every 3 Hours** *(charlie)*

> Objective: Schedule tasks using at, cron and systemd timer units

1. `at`: schedule for 3 minutes from now: append `"at-fired $(date)"` to `/var/log/at_lab.log`
2. `cron`: as `emma`, run `df -h > ~/disk_report.log` every **weekday at 07:15**
3. `systemd timer`:
   - Service `/etc/systemd/system/labhealth.service` runs `/usr/local/bin/labhealth.sh`
   - Script writes `uptime`, `free -m`, and `df -h /` to `/var/log/labhealth.log`
   - Timer `/etc/systemd/system/labhealth.timer` fires **every 3 hours**, `Persistent=true`
   - Enable timer, verify with `systemctl list-timers --all`

---

### SECTION 9: Shell Scripting

---

**Task 30 — Argument Parser with `case` Statement** *(charlie)*

> Objective: Conditionally execute code; Process script inputs

Write `/usr/local/bin/svcctl.sh` that:

- Takes **two** arguments: `<action>` and `<service>`
- Valid actions: `start`, `stop`, `restart`, `status`, `check`
- `check` should print `RUNNING` or `STOPPED` based on `systemctl is-active`
- Any other action → print usage to `stderr` and exit `2`
- If service does not exist (`systemctl cat` fails), print `"Unknown service"` and exit `3`
- Return proper exit codes; test with `bash -x`

Use a `case` statement, not chained `if/elif`.

---

**Task 31 — While-Read Loop That Processes a CSV** *(charlie)*

> Objective: Use looping constructs; Processing output of shell commands within a script

Write `/usr/local/bin/csv_users.sh`:

- Input file `/root/newusers.csv` with format `username,uid,gid,fullname`:

  ivan,2200,6000,Ivan Petrov
  julia,2201,6000,Julia Kim
  kai,2202,6001,Kai Nguyen
- For each line:

  - Skip lines starting with `#` or blank lines
  - Create the user with the given UID, GID (assume group exists), and full name as comment
  - Set a random password generated with `openssl`
  - Append `username,password` to `/root/passwords.txt` (mode `0600`)
- Use `while IFS=, read -r ...` and `[[ ... ]]` tests

---

**Task 32 — Reporting Script with Trap and Cleanup** *(charlie)*

> Objective: Process output of shell commands within a script

Write `/root/health_report.sh`:

- Collects: hostname, kernel, uptime, load, top 5 CPU processes, disk usage, failed systemd units
- Writes to `/tmp/health.$$.tmp` first, then atomically moves to `/var/log/health/$(hostname)-$(date +%F).log`
- Uses `trap` to clean up the tmp file on error/interrupt
- Rotates: keep only 14 daily reports
- Schedule via **cron** at `06:00` every day **except the 1st of the month**

---

### SECTION 10: SELinux

---

**Task 33 — SELinux for a Custom Web Root** *(charlie)*

> Objective: Set enforcing/permissive modes; list/identify SELinux file & process context; restore contexts

1. Confirm SELinux is `enforcing`; if not, set it permanently
2. Install `httpd`, enable, start
3. Create `/srv/websites/site1/`; add `index.html` = `"Site1 charlie"`
4. Configure `httpd` to use `/srv/websites/site1/` as `DocumentRoot` (drop-in `/etc/httpd/conf.d/site1.conf`)
5. On restart, `httpd` fails or serves 403 — diagnose it from the journal and the audit log
6. Apply the correct persistent file context for `/srv/websites` and everything below it
7. Verify with `curl http://localhost/` → returns `"Site1 charlie"`
8. Confirm the process context of `httpd`

---

**Task 34 — Non-Standard SSH Port with SELinux + Booleans** *(charlie)*

> Objective: Manage SELinux port labels; use Boolean settings

1. Configure `sshd` to listen on **port 2222** in addition to 22
2. Add `2222/tcp` to the SELinux policy so sshd may bind it
3. Add firewall rule for port `2222/tcp` in `labzone` (persistent)
4. Restart `sshd`, confirm it is listening on both ports
5. Enable persistently the boolean `ssh_sysadm_login` (or `use_nfs_home_dirs` if not present) and verify
6. Set the boolean `httpd_can_network_connect_db` on persistently
7. Copy `/etc/motd` to `/var/www/html/motd.txt`; observe its context is `admin_home_t` or `etc_t`; fix it so it becomes `httpd_sys_content_t`

---

### SECTION 11: Essential Tools — Text, Redirection & Archives

---

**Task 35 — grep, Redirection, `su -` and an xz Archive** *(charlie)*

> Objective: Use input-output redirection, Use grep and regular expressions to analyze text, Log in and switch users in multiuser targets, Archive, compress, unpack, and uncompress files using tar

1. Using a **single** `grep -E` with an anchored regex, extract the `/etc/passwd` lines for UIDs `2100`–`2103` into `/root/exam_users.txt`. No other lines may match.
2. Append (do not overwrite) the output of `date` to `/root/exam_users.txt`
3. Save only the **active** lines of `/etc/ssh/sshd_config` (no comments, no blank lines) to `/root/sshd_active.txt`
4. Switch to `emma` with a **login shell**. As `emma`, run `find /etc -name '*.conf'`, sending the paths found to `~/conf_list.txt` and the error messages to `~/conf_errors.txt`. Nothing may print to the terminal.
5. As `root`, create an **xz**-compressed archive `/root/sshconf.tar.xz` of `/etc/ssh`
6. Extract **only** `sshd_config` from the archive into `/root/restore/`

---

## 📊 Grading Checklist

| #  | Task                                              | Reboot Test | Done |
| -- | ------------------------------------------------- | :---------: | :--: |
| 1  | Recover root via`init=/bin/bash`                |     ✓     | [ ] |
| 2  | Change default target rescue → graphical         |     ✓     | [ ] |
| 3  | Bootloader: kernel args + dracut rebuild          |     ✓     | [ ] |
| 4  | Static IPv4/IPv6 + DNS +`lab-static` connection |     ✓     | [ ] |
| 5  | Firewalld custom zone + rich rule                 |     ✓     | [ ] |
| 6  | Users/groups w/ custom home & shell               |     ✓     | [ ] |
| 7  | Password aging + pwquality policy                 |     ✓     | [ ] |
| 8  | Sudo user/cmd aliases + NOPASSWD                  |     ✓     | [ ] |
| 9  | ACL project directory                             |     ✓     | [ ] |
| 10 | Per-group umask + hard/soft links                 |     ✓     | [ ] |
| 11 | SSH key auth + Match block for emma               |     ✓     | [ ] |
| 12 | rsync w/ bwlimit + sftp batch + sha256            |     —     | [ ] |
| 13 | Two repo files + GPG import + priorities          |     ✓     | [ ] |
| 14 | Flatpak remote add + install/uninstall            |     —     | [ ] |
| 15 | RPM verify/tamper/reinstall                       |     —     | [ ] |
| 16 | GPT partitions via`parted -s`                   |     ✓     | [ ] |
| 17 | XFS by UUID + VFAT by LABEL, noexec/nodev/nosuid  |     ✓     | [ ] |
| 18 | Swap**file** priority 20                    |     ✓     | [ ] |
| 19 | Striped LV + 32 MiB PE                            |     ✓     | [ ] |
| 20 | `pvmove`, `vgreduce`, extend to 100% FREE     |     ✓     | [ ] |
| 21 | NFSv4-only server, disable v3                     |     ✓     | [ ] |
| 22 | NFS client w/`_netdev,nofail`                   |     ✓     | [ ] |
| 23 | AutoFS wildcard indirect + ghost + 60s timeout    |     ✓     | [ ] |
| 24 | Permission repair + suid inventory                |     ✓     | [ ] |
| 25 | Chrony server on delta, client on charlie         |     ✓     | [ ] |
| 26 | Tuned custom profile inheriting parent            |     ✓     | [ ] |
| 27 | Nice + cgroup CPUQuota + pkill                    |     —     | [ ] |
| 28 | Persistent journal + rsyslog + logrotate          |     ✓     | [ ] |
| 29 | at + cron + systemd timer OnCalendar 3h           |     ✓     | [ ] |
| 30 | `case`-based service control script             |     —     | [ ] |
| 31 | CSV`while read` user creation                   |     —     | [ ] |
| 32 | Health report + trap + rotation cron              |     ✓     | [ ] |
| 33 | SELinux fcontext for custom DocumentRoot          |     ✓     | [ ] |
| 34 | SELinux port label 2222 + booleans                |     ✓     | [ ] |
| 35 | grep -E + redirection + su - + tar.xz             |     ✓     | [ ] |

**Score: ___ / 35**
**Passing threshold (~70%): 25 / 35**

---

## ✅ Quick Verification Script

Run on the relevant host **after a reboot**. Checks the objectively-verifiable, persistence-sensitive items only — a safety net against marking something "done" that didn't actually persist, not a full grader. Tasks needing human judgement (T11 SSH keys, T12 transfers, T30–32 script behaviour) aren't covered.

```bash
#!/usr/bin/env bash
# ex2-verify.sh — spot-check Exam 2 persistence. Run with sudo on each host.
pass=0; fail=0
chk() { # chk "label" "command"
  if eval "$2" &>/dev/null; then printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1))
  else printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); fi
}

echo "== Host: $(hostname -s) =="

case "$(hostname -s)" in
  *charlie*)
    chk "T3  audit=1 in cmdline"        "grep -q 'audit=1' /proc/cmdline"
    chk "T3  net.ifnames=0 in cmdline"  "grep -q 'net.ifnames=0' /proc/cmdline"
    chk "T3  quiet removed"             "! grep -q ' quiet' /proc/cmdline"
    chk "T4  hostname charlie"          "hostnamectl --static | grep -qx charlie.ex200.lab"
    chk "T4  IPv4 10.20.30.11"          "ip -4 addr show | grep -q '10.20.30.11'"
    chk "T4  IPv6 fd42::11"             "ip -6 addr show | grep -q 'fd42::11'"
    chk "T4  lab-static autoconnect"    "nmcli -g connection.autoconnect con show lab-static | grep -qi yes"
    chk "T5  labzone is default"        "firewall-cmd --get-default-zone | grep -qx labzone"
    chk "T5  labzone ports 9000-9010"   "firewall-cmd --zone=labzone --list-ports | grep -q 9000-9010"
    chk "T5  labzone has ssh"           "firewall-cmd --zone=labzone --list-services | grep -q ssh"
    chk "T6  emma uid 2100"             "id -u emma | grep -qx 2100"
    chk "T6  ops gid 6000"              "getent group ops | grep -q ':6000:'"
    chk "T6  emma home /srv/users/emma" "getent passwd emma | grep -q /srv/users/emma"
    chk "T6  henry nologin"             "getent passwd henry | grep -qE '(nologin|false)$'"
    chk "T7  pwquality minlen 12"       "grep -qE '^\\s*minlen\\s*=\\s*12' /etc/security/pwquality.conf"
    chk "T7  emma max 45 days"          "chage -l emma | grep -qi 'Maximum.*45'"
    chk "T8  sudoers valid"             "visudo -c &>/dev/null"
    chk "T8  lab_sudo has OPSTEAM"      "grep -q OPSTEAM /etc/sudoers.d/lab_sudo"
    chk "T9  phoenix 2770"              "stat -c '%a' /srv/project/phoenix | grep -qx 2770"
    chk "T9  frank access ACL"          "getfacl /srv/project/phoenix 2>/dev/null | grep -q '^user:frank:rwx'"
    chk "T9  default ACL present"       "getfacl /srv/project/phoenix 2>/dev/null | grep -q '^default:'"
    chk "T10 ops umask drop-in"         "grep -rq '0027' /etc/profile.d/"
    chk "T13 two repo files"            "test -f /etc/yum.repos.d/lab-baseos.repo -a -f /etc/yum.repos.d/lab-appstream.repo"
    chk "T13 gpgcheck enabled"          "grep -q 'gpgcheck=1' /etc/yum.repos.d/lab-baseos.repo"
    chk "T17 charliexfs mounted"        "findmnt /mnt/charliexfs"
    chk "T17 usbdata noexec"            "findmnt -no OPTIONS /mnt/usbdata | grep -q noexec"
    chk "T17 usbdata by LABEL"          "grep '/mnt/usbdata' /etc/fstab | grep -q 'LABEL=USBDATA'"
    chk "T19 vg_lab2 32M PE"            "vgs --noheadings -o vg_extent_size vg_lab2 | grep -q '32'"
    chk "T19 stripe mounted"            "findmnt /mnt/stripe"
    chk "T19 home2 mounted"             "findmnt /mnt/home2"
    chk "T20 vdd removed from VG"       "! pvs --noheadings -o pv_name | grep -q /dev/vdd"
    chk "T22 projects mounted"          "findmnt /mnt/projects"
    chk "T22 archive read-only"         "findmnt -no OPTIONS /mnt/archive | grep -q '\\bro\\b'"
    chk "T23 autofs enabled"            "systemctl is-enabled --quiet autofs"
    chk "T24 finance 2750 gina:ops"     "stat -c '%a %U:%G' /opt/finance | grep -qx '2750 gina:ops'"
    chk "T24 private 0700"              "stat -c '%a' /opt/finance/private | grep -qx 700"
    chk "T24 suid list saved"           "test -s /root/suid_list.txt"
    chk "T25 chrony uses delta"         "grep -qE '^server +delta' /etc/chrony.conf"
    chk "T25 timezone London"           "timedatectl show -p Timezone --value | grep -qx Europe/London"
    chk "T26 lab-highio active"         "tuned-adm active | grep -q lab-highio"
    chk "T26 swappiness 10"             "sysctl -n vm.swappiness | grep -qx 10"
    chk "T28 journal persistent"        "test -d /var/log/journal"
    chk "T28 ForwardToSyslog"           "grep -qsE '^ForwardToSyslog=yes' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf"
    chk "T28 secure.lab rule"           "grep -q 'secure.lab' /etc/rsyslog.conf /etc/rsyslog.d/* 2>/dev/null"
    chk "T28 logrotate config"          "test -f /etc/logrotate.d/secure.lab"
    chk "T29 labhealth timer enabled"   "systemctl is-enabled --quiet labhealth.timer"
    chk "T29 emma weekday cron"         "crontab -l -u emma 2>/dev/null | grep -q '1-5'"
    chk "T32 health_report cron"        "crontab -l 2>/dev/null | grep -q 'health_report.sh'"
    chk "T33 SELinux enforcing"         "getenforce | grep -qx Enforcing"
    chk "T33 websites labeled"          "ls -Zd /srv/websites | grep -q httpd_sys_content_t"
    chk "T33 site1 serving"             "curl -sf http://localhost/ | grep -q 'Site1 charlie'"
    chk "T34 port 2222 labeled"         "semanage port -l | grep ssh_port_t | grep -q 2222"
    chk "T34 sshd on 2222"              "ss -tlnp | grep -q ':2222'"
    chk "T34 labzone has 2222"          "firewall-cmd --zone=labzone --list-ports | grep -q 2222"
    chk "T34 httpd_can_network_connect_db" "getsebool httpd_can_network_connect_db | grep -q ' on$'"
    chk "T35 exam_users has 4 UIDs"     "test \$(grep -cE ':210[0-3]:' /root/exam_users.txt) -eq 4"
    chk "T35 sshd_active no comments"   "test -s /root/sshd_active.txt && ! grep -qE '^\\s*(#|$)' /root/sshd_active.txt"
    chk "T35 emma owns conf_list"       "stat -c '%U' /srv/users/emma/conf_list.txt | grep -qx emma"
    chk "T35 conf_errors captured"      "test -s /srv/users/emma/conf_errors.txt"
    chk "T35 tar.xz has sshd_config"    "tar -tJf /root/sshconf.tar.xz | grep -q sshd_config"
    chk "T35 sshd_config restored"      "test -f /root/restore/etc/ssh/sshd_config"
    ;;
  *delta*)
    chk "T2  default graphical"         "systemctl get-default | grep -qx graphical.target"
    chk "T4  hostname delta"            "hostnamectl --static | grep -qx delta.ex200.lab"
    chk "T4  IPv4 10.20.30.12"          "ip -4 addr show | grep -q '10.20.30.12'"
    chk "T4  IPv6 fd42::12"             "ip -6 addr show | grep -q 'fd42::12'"
    chk "T10 hard link demo"            "test -f /root/link_notes.txt"
    chk "T11 PermitRootLogin prohibit"  "sshd -T 2>/dev/null | grep -qiE 'permitrootlogin (prohibit|without)-password'"
    chk "T11 AllowUsers set"            "sshd -T 2>/dev/null | grep -qi '^allowusers'"
    chk "T11 sshd config valid"         "sshd -t"
    chk "T18 swap file active"          "swapon --show | grep -q /swap/extraswap.img"
    chk "T18 swap priority 20"          "swapon --show=PRIO --noheadings | grep -q 20"
    chk "T18 swapfile mode 0600"        "stat -c '%a' /swap/extraswap.img | grep -qx 600"
    chk "T21 nfs-server running"        "systemctl is-active --quiet nfs-server"
    chk "T21 nfsv3 disabled"            "grep -qE '^\\s*vers3\\s*=\\s*n' /etc/nfs.conf"
    chk "T21 projects exported"         "exportfs -v | grep -q /srv/nfs/projects"
    chk "T25 chrony allows subnet"      "grep -qE '^allow +10\\.20\\.30\\.0/24' /etc/chrony.conf"
    chk "T25 timezone Tokyo"            "timedatectl show -p Timezone --value | grep -qx Asia/Tokyo"
    ;;
esac

echo "== $pass passed, $fail failed =="
```

---

---

# 🔑 ANSWER KEY

> **Stop.** Do not read this during a timed run. Score yourself from the checklist first, then come back here for the tasks you missed.

> **Conventions:**
>
> - **Commands assume you're a regular admin user** (e.g. `student`) with sudo rights. Commands that need root are prefixed with `sudo`. Checks that any user can run (`ls`, `id`, `getent`, `findmnt`, `ip`, ...) have no prefix.
> - **Redirecting into root-owned files:** `sudo cmd > /root/file` fails, because the shell does the `>` as **you** before sudo runs. Use `cmd | sudo tee /root/file > /dev/null` instead, with `tee -a` in place of `>>`. Heredocs into protected files use `sudo tee FILE > /dev/null <<'EOF'`.
> - **Working in a root shell** (`sudo -i`, or how the real EX200 usually starts you)? Drop every `sudo` and use plain `>` / `>>`.
> - **File-content blocks** (`.repo`, unit files, scripts, config snippets) show what goes **in** the file. Create them with `sudo vim FILE`. Scripts run as root, so they have no `sudo` inside.
> - **`su - emma`** asks for emma's password (`Init!Pass2026` from T7). `sudo su - emma` skips the prompt.
> - Each task ends with a **Verify** block. Run it, because "I typed the command" doesn't count as done.

---

### Section 1 — System Recovery & Boot Management

**T1 — Break-in via `init=/bin/bash`** *(charlie)*

```bash
# 1. Reboot; at the GRUB menu press any arrow key to stop the countdown
# 2. Highlight the default entry, press 'e'
# 3. On the line starting with 'linux':  change ' ro ' -> ' rw '  and append:  init=/bin/bash
# 4. Ctrl-X to boot. You land in a root bash shell with no systemd running (PID 1 = bash)

mount | grep ' / '          # confirm (rw,...); if it shows ro:
mount -o remount,rw /
passwd root                 # Ex200Pass!   (or: echo 'Ex200Pass!' | passwd --stdin root)
touch /.autorelabel         # SELinux policy wasn't loaded, so /etc/shadow got the wrong label
sync
exec /sbin/init             # hand PID 1 to systemd. Alternative: /sbin/reboot -f
```

- **No `sudo` in this task.** The recovery shell is already root, and nothing else (systemd, PAM, logins) is running yet.
- **What `rw` + `init=/bin/bash` does:** the initramfs still mounts the real root and switches to it, then bash runs as PID 1 in place of systemd. `rw` leaves root writable, and there's no `chroot /sysroot`.
- **Plain `reboot` does not work.** It talks to systemd, which isn't running. Use `exec /sbin/init` or `reboot -f`.
- **No `/.autorelabel` means a locked-out root.** `/etc/shadow` gets mislabeled, PAM can't read it under enforcing mode, and root login fails even with the right password.
- The relabel reboot takes a minute or two and then reboots again. That's expected.
- *Faster alternative to a full relabel:* `/usr/sbin/load_policy -i` before `passwd`, then `restorecon -v /etc/shadow`. `touch /.autorelabel` is the safe answer on the exam.

**Verify:** log in on the console as `root` / `Ex200Pass!`, then `getenforce` → `Enforcing`.

---

**T2 — Rescue → graphical** *(delta)*

```bash
# delta boots into rescue.target, so you get a root password prompt on the console
systemctl get-default                   # rescue.target
sudo systemctl set-default graphical.target  # just repoints the /etc/systemd/system/default.target symlink

# Graphical target needs a GUI installed. Without one it falls back to a text login.
# delta needs a repo first: mount the DVD and create the repo files as in Task 13 (see the T13 delta note)
dnf group list --hidden | grep -i gui
sudo dnf group install -y "Server with GUI"

sudo systemctl reboot
```

**Verify (after reboot):**

```bash
systemctl get-default       # graphical.target
runlevel                    # N 5
systemctl is-active gdm     # active (if the GUI group installed)
ls -l /etc/systemd/system/default.target
```

- `sudo systemctl isolate graphical.target` switches **now** without a reboot. It does **not** change the default. `set-default` changes the default but does **not** switch now. The task needs `set-default`.
- **No repo on delta yet?** Do the `set-default` part now and install the group once delta has its repos (T13 delta note). The target change is what gets graded.

---

**T3 — Bootloader: remove quiet, add kernel args** *(charlie)*

```bash
sudo vim /etc/default/grub
#   GRUB_TIMEOUT=5
#   GRUB_CMDLINE_LINUX="... crashkernel=... resume=... rd.lvm.lv=... audit=1 net.ifnames=0"
#   (delete 'rhgb' and 'quiet'; leave everything else on the line alone)

# RHEL 10 uses BLS entries (/boot/loader/entries/*.conf). Plain grub2-mkconfig does NOT
# rewrite the options inside existing BLS entries. Use --update-bls-cmdline:
sudo grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline
sudo dracut -f              # task asks for it; rebuilds initramfs for the running kernel
sudo reboot
```

**Equivalent `grubby` method.** This works on any RHEL 8+ system and is often what graders expect:

```bash
sudo grubby --update-kernel=ALL --remove-args="rhgb quiet" --args="audit=1 net.ifnames=0"
sudo grubby --info=DEFAULT | grep args
```

Do both: edit `/etc/default/grub` so **future** kernels inherit the args, and use `--update-bls-cmdline` or `grubby` so **installed** kernels get them now.

**Verify:**

```bash
cat /proc/cmdline                       # audit=1 net.ifnames=0 present; no rhgb, no quiet
grep TIMEOUT /etc/default/grub
sudo grubby --info=ALL | grep ^args
```

- **On UEFI, still write to `/boot/grub2/grub.cfg`.** Since RHEL 9 the file at `/boot/efi/EFI/redhat/grub.cfg` is a small stub that points at the BIOS-path file. Overwriting the stub breaks boot.
- **`net.ifnames=0` renames the NIC to `eth0`.** Do this task **before** Tasks 4/5. If you do it after, the `lab-static` profile is still bound to the old interface name (`enp1s0` etc.) and won't come up. Fix it with `sudo nmcli con mod lab-static connection.interface-name eth0`.

---

### Section 2 — Networking & Hostname

**T4 — `nmcli` static IPv4/IPv6 + DNS** *(both nodes; charlie values shown)*

```bash
sudo hostnamectl set-hostname charlie.ex200.lab

nmcli device status                     # find the interface name (eth0 after Task 3)
nmcli con show                          # find the existing profile name

# Rename the existing profile (e.g. "eth0" or "Wired connection 1") to lab-static
sudo nmcli con mod "<old profile>" connection.id lab-static

# IPv4: set the address BEFORE method=manual (manual with no address is rejected)
sudo nmcli con mod lab-static ipv4.addresses 10.20.30.11/24
sudo nmcli con mod lab-static ipv4.gateway 10.20.30.1
sudo nmcli con mod lab-static ipv4.dns "10.20.30.1 1.1.1.1"
sudo nmcli con mod lab-static ipv4.method manual

# IPv6: same order
sudo nmcli con mod lab-static ipv6.addresses fd42::11/64
sudo nmcli con mod lab-static ipv6.method manual

sudo nmcli con mod lab-static connection.autoconnect yes

sudo nmcli con up lab-static            # changes don't apply until the profile is re-activated
```

Add to `/etc/hosts` on **both** nodes:

```text
10.20.30.11   charlie.ex200.lab   charlie
10.20.30.12   delta.ex200.lab     delta
```

On delta, use the same commands with `delta.ex200.lab`, `10.20.30.12/24` and `fd42::12/64`.

**Verify:**

```bash
nmcli -g ipv4.addresses,ipv4.gateway,ipv4.dns,ipv6.addresses,connection.autoconnect con show lab-static
ip -br addr
cat /etc/resolv.conf                    # nameserver 10.20.30.1 / 1.1.1.1 (written by NM)
hostnamectl --static
ping -c2 delta && ping -c2 charlie
ping -6 -c2 fd42::12                    # from charlie
```

- **"Connection alias"** means the NetworkManager **connection name** (`connection.id`). There is no separate alias field.
- **Don't edit `/etc/resolv.conf` by hand.** NetworkManager overwrites it. DNS goes in `ipv4.dns`.
- On RHEL 10 the profile lives in `/etc/NetworkManager/system-connections/lab-static.nmconnection` (keyfile format). The legacy `ifcfg` files are gone.
- `nmcli con mod` changes don't apply until `nmcli con up lab-static` (or a reboot).
- **Use Tab completion.** `sudo nmcli con mod lab-static ipv4.<Tab><Tab>` lists every property, so you don't need to memorise the names. `man nmcli-examples` has ready-made static-IP examples.
- **Order matters.** `ipv4.method manual` fails with *"ipv4.addresses: this property cannot be empty"* if no address is set yet. Set the address first, as above.
- **Shorthand aliases.** `ip4`, `gw4`, `ip6` and `gw6` work in place of `ipv4.addresses`, `ipv4.gateway`, etc. Run `nmcli -g ipv4.method con show lab-static` afterwards to make sure the method really is `manual`.
- **Renaming beats adding a second profile.** If you `nmcli con add` a new one instead, set the old profile to `connection.autoconnect no`, or both profiles compete for `eth0` at boot.

---

**T5 — Custom firewalld zone + rich rule** *(charlie)*

```bash
sudo firewall-cmd --permanent --new-zone=labzone
sudo firewall-cmd --reload                             # zone must exist at runtime before NM can use it

# Bind the connection to the zone through NetworkManager (persists in the profile)
sudo nmcli con mod lab-static connection.zone labzone
sudo nmcli con up lab-static

sudo firewall-cmd --permanent --zone=labzone --add-service={ssh,https,dns}
sudo firewall-cmd --permanent --zone=labzone --add-port=9000-9010/tcp
sudo firewall-cmd --permanent --zone=labzone \
  --add-rich-rule='rule family="ipv4" source address="10.20.30.100" drop'
sudo firewall-cmd --set-default-zone=labzone           # always both runtime + permanent
sudo firewall-cmd --reload

# The "for 60s" part: timeouts work at RUNTIME only (they can't be combined with --permanent)
sudo firewall-cmd --zone=labzone \
  --add-rich-rule='rule family="ipv4" source address="10.20.30.100" drop' --timeout=60s
```

**Verify:**

```bash
sudo firewall-cmd --get-default-zone                   # labzone
sudo firewall-cmd --get-active-zones                   # labzone  interfaces: eth0
sudo firewall-cmd --list-all --zone=labzone
sudo firewall-cmd --permanent --list-all --zone=labzone     # what survives reboot
```

- **The task's "drop for 60s" is a trick.** `--timeout` and `--permanent` are mutually exclusive, so firewalld can't store a timed rule. The persistent answer is the permanent `drop` rule. The 60-second variant is a runtime demonstration only. Know this: on the exam, a rule that disappears at reboot scores zero.
- **Assign the zone through NetworkManager, not firewalld.** For NM-managed interfaces, `nmcli con mod ... connection.zone` is the correct persistent method. `sudo firewall-cmd --permanent --change-interface=eth0` works too, but NetworkManager can override it on reconnect.
- `drop` silently discards packets. `reject` sends an ICMP error back.
- **Leave `ssh` in the zone.** Removing it, or switching the default zone before adding it, locks you out of an SSH session.

---

### Section 3 — Users, Groups & Permissions

**T6 — Users & groups** *(charlie)*

```bash
sudo groupadd -g 6000 ops
sudo groupadd -g 6001 qateam
sudo groupadd -r -g 6002 auditors       # -r = system group (explicit GID still wins)

sudo dnf install -y zsh
sudo mkdir -p /srv/users                # useradd -m creates the home dir, not its parent

sudo useradd -u 2100 -g ops -G qateam -d /srv/users/emma -m emma
sudo useradd -u 2101 -g qateam -G auditors -s /bin/zsh frank
sudo useradd -u 2102 -g ops -c "Gina — DBA" gina
sudo useradd -u 2103 -g auditors -s /sbin/nologin henry

# SELinux: give /srv/users the same labels as /home (otherwise ssh keys, etc. fail later)
sudo semanage fcontext -a -e /home /srv/users
sudo restorecon -Rv /srv/users
```

**Verify:**

```bash
getent group ops qateam auditors
id emma; id frank; id gina; id henry
getent passwd emma frank gina henry     # check home, shell, comment fields
ls -ld /srv/users/emma /home/frank /home/gina /home/henry     # drwx------
ls -Zd /srv/users/emma                  # user_home_dir_t
```

- Home directories come out `700` because RHEL sets `HOME_MODE 0700` in `/etc/login.defs`. If one isn't `700`, run `sudo chmod 700 DIR`.
- **`-g` vs `-G`:** `-g` sets the **primary** group. `-G` sets the **supplementary** list. To add a group later without dropping existing ones, use `sudo usermod -aG GROUP USER`. Without `-a`, it **replaces** the whole list.
- `/bin/zsh` must exist **before** you use it with `-s`, or `useradd` warns and frank can't log in.
- If you forget `-d` and have to move a home later: `sudo usermod -d /srv/users/emma -m emma`.

---

**T7 — Password aging + pwquality** *(charlie)*

```bash
# Set passwords FIRST, before tightening pwquality
for u in emma frank gina henry; do echo 'Init!Pass2026' | sudo passwd --stdin "$u"; done
# (portable alternative: echo 'emma:Init!Pass2026' | sudo chpasswd)

sudo chage -m 3 -M 45 -W 7 -I 14 emma
sudo chage -d 0 frank                   # last change = epoch → forced change at next login
sudo chage -I 5 frank                   # account locks 5 days after the password expires
sudo chage -E 2027-01-01 gina

sudo vim /etc/security/pwquality.conf   # or a drop-in: /etc/security/pwquality.conf.d/lab.conf
#   minlen = 12
#   dcredit = -1
#   ucredit = -1
#   ocredit = -1
```

**Test the policy.** As root, `passwd` only *warns* (root can override), so test as the user:

```bash
echo 'short1' | pwscore                 # quick check: prints the failure reason
su - gina -c passwd                     # old pw Init!Pass2026, then try "password" → BAD PASSWORD
```

**Verify:**

```bash
sudo chage -l emma  # Min 3, Max 45, Warn 7, Inactive 14
sudo chage -l frank # "Password must be changed", Inactive 5
sudo chage -l gina  # Account expires: Jan 01, 2027
grep -Ev '^\s*(#|$)' /etc/security/pwquality.conf
```

- **Negative credits mean a minimum count.** `dcredit = -1` requires at least 1 digit. A positive value instead gives *length credit* per digit, which is a different behaviour.
- `sudo chage -d 0 frank` and `sudo passwd -e frank` do the same thing.
- To apply the policy to root too, add `enforce_for_root` to `pwquality.conf`. The task doesn't ask for it.
- `Init!Pass2026` is 13 characters with an uppercase letter, digits and a symbol, so it already passes the new policy.

---

**T8 — Sudo aliases** *(charlie)*

```bash
sudo visudo -f /etc/sudoers.d/lab_sudo
```

```text
User_Alias  OPSTEAM  = emma, gina
User_Alias  QAUSERS  = frank
Cmnd_Alias  NETADMIN = /usr/bin/nmcli, /usr/sbin/ip, /usr/sbin/ss
Cmnd_Alias  SVCMGMT  = /usr/bin/systemctl status *, /usr/bin/systemctl restart httpd

OPSTEAM   ALL=(ALL)  NOPASSWD: NETADMIN
QAUSERS   ALL=(ALL)  SVCMGMT
%auditors ALL=(ALL)  /usr/bin/cat /var/log/*
```

```bash
sudo chmod 440 /etc/sudoers.d/lab_sudo
sudo visudo -cf /etc/sudoers.d/lab_sudo # "parsed OK"
```

**Verify:**

```bash
sudo -l -U emma     # (ALL) NOPASSWD: /usr/bin/nmcli, /usr/sbin/ip, /usr/sbin/ss
sudo -l -U frank    # (ALL) /usr/bin/systemctl status *, ...
sudo -l -U henry    # (ALL) /usr/bin/cat /var/log/*
su - emma -c 'sudo ss -tln'             # no password prompt
```

- **Alias names must be UPPERCASE.** Group names take a `%` prefix. Commands need **full paths**: check them with `command -v nmcli ip ss`.
- **Always use `visudo -f`.** It refuses to save a syntax error. A broken file in `sudoers.d` breaks `sudo` for everyone.
- `sudoers.d` ignores files whose names contain a `.` or end in `~`, so `lab_sudo` is fine and `lab.sudo` would be silently ignored.
- `cat /var/log/*` is not safe: `sudo cat /var/log/../../etc/shadow` matches the wildcard. Real-world fix: `sudoedit` or `less` with `NOEXEC`. Worth knowing; not graded.

---

**T9 — ACL project directory** *(charlie)*

```bash
sudo mkdir -p /srv/project/phoenix
sudo chown gina:ops /srv/project/phoenix
sudo chmod 2770 /srv/project/phoenix

sudo setfacl -m u:frank:rwx,g:auditors:rx,u:henry:--- /srv/project/phoenix     # access ACL
sudo setfacl -d -m u:frank:rwx,g:auditors:rx,u:henry:--- /srv/project/phoenix  # default ACL
```

**Verify:**

```bash
getfacl /srv/project/phoenix
ls -ld /srv/project/phoenix             # drwxrws---+   ← the '+' means an ACL is present

sudo -u gina  bash -c 'echo hello > /srv/project/phoenix/plan.txt'
getfacl /srv/project/phoenix/plan.txt   # inherited user:frank:rwx, group:auditors:r-x, user:henry:---
sudo -u frank bash -c 'echo edit >> /srv/project/phoenix/plan.txt' && echo "frank OK"
sudo -u henry cat /srv/project/phoenix/plan.txt    # Permission denied
```

- **"Read-only" on a directory means `r-x`.** Without `x` the auditors can list names but can't open or `cd` into anything.
- **henry's named entry wins over his group.** henry's primary group is `auditors`, which has `r-x`. ACL evaluation checks named-user entries **before** group entries, so `user:henry:---` blocks him.
- **Watch the `mask`.** It caps every named entry and the group entry. A later `chmod g-w` on the directory lowers the mask and silently takes away frank's write. Re-run `sudo setfacl -m m::rwx /srv/project/phoenix` to restore it.
- henry has a `nologin` shell, so `su - henry` fails. `sudo -u henry CMD` still works for testing.
- Files gina creates get group `ops` from the SGID bit, and their ACL comes from the default entries.

---

**T10 — Per-group umask + links**

charlie, `/etc/profile.d/ops-umask.sh`:

```bash
sudo tee /etc/profile.d/ops-umask.sh > /dev/null <<'EOF'
# umask 0027 for members of ops; everyone else keeps the distro default
if id -nG | grep -qw ops; then
    umask 0027
fi
EOF
sudo chmod 644 /etc/profile.d/ops-umask.sh
```

**Verify:**

```bash
su - emma -c umask       # 0027
su - frank -c umask      # 0022 (frank isn't in ops)
```

> frank's shell is zsh, which doesn't read `/etc/profile.d/` by default. That's fine for frank, who isn't in ops anyway. Just be aware that profile.d is bash/sh-only.

delta:

```bash
sudo mkdir -p /opt/data
echo "exam data" | sudo tee /opt/data/original.txt
sudo ln /opt/data/original.txt /opt/data/hardlink.txt     # hard link: same inode
sudo ln -s /opt/data/original.txt /root/softlink.txt      # symlink: own inode, stores a path

sudo ls -li /opt/data/ /root/softlink.txt    # same inode number on original + hardlink; link count 2
sudo rm /opt/data/original.txt
cat /opt/data/hardlink.txt              # exam data   ← still works
sudo cat /root/softlink.txt             # No such file or directory  ← dangling
sudo ls -l /root/softlink.txt           # shown in red / points to a missing target

sudo tee /root/link_notes.txt > /dev/null <<'EOF'
# Hard link = a second directory entry for the SAME inode. Data survives until the
#   link count reaches 0, so deleting original.txt left hardlink.txt intact.
#   Can't cross filesystems and can't link directories.
# Soft link = its own inode that stores a PATH. When the target path is removed the
#   symlink dangles. Can cross filesystems and can point to directories.
EOF
```

- Use **absolute** paths for symlink targets unless you specifically want a relative link. A relative target is resolved from the **link's** directory, not from your current directory.

---

### Section 4 — SSH & Remote Access

**T11 — SSH keys + `Match User`**

charlie, as root. The task wants **root's** key, so switch to a root shell for this part:

```bash
sudo -i                                                   # root login shell; ~ is now /root
ssh-keygen -t ecdsa -b 521 -N '' -f ~/.ssh/id_ecdsa       # nistp521 = ecdsa with 521 bits
ssh-copy-id -i ~/.ssh/id_ecdsa.pub root@delta             # needs delta root pw login to still work
ssh root@delta hostname                                   # no password prompt
exit                                                      # back to your own user
```

> From now on, `sudo ssh root@delta ...`, `sudo scp`, `sudo rsync` and `sudo sftp` use root's key. ssh finds the key through root's home directory, not your `$HOME`.

delta (emma with the **same UID**, and ideally the same GID so NFS ownership matches later):

```bash
sudo groupadd -g 6000 ops
sudo useradd -u 2100 -g ops emma
echo 'Init!Pass2026' | sudo passwd --stdin emma          # needed once so ssh-copy-id can log in
```

charlie, as emma:

```bash
su - emma
ssh-keygen -t ed25519 -N 'Lab#2026' -f ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub emma@delta
eval "$(ssh-agent)"; ssh-add                              # enter passphrase once
ssh emma@delta hostname
exit
```

delta, sshd config. Do key setup **before** turning password auth off. RHEL 10's `sshd_config` starts with `Include /etc/ssh/sshd_config.d/*.conf`, and **sshd keeps the first value it reads for each keyword**. Check for an installer-created override first:

```bash
sudo grep -r PermitRootLogin /etc/ssh/sshd_config.d/   # e.g. 01-permitrootlogin.conf: PermitRootLogin yes
# Delete or change that file. Otherwise it wins over anything below it
```

`/etc/ssh/sshd_config.d/10-lab.conf`:

```text
PermitRootLogin prohibit-password
AllowUsers root emma frank
```

Append the `Match` block at the **very end** of `/etc/ssh/sshd_config`. Everything after a `Match` line belongs to that block until the next `Match` or end of file:

```text
Match User emma
    PasswordAuthentication no
```

```bash
sudo sshd -t && sudo systemctl reload sshd
```

**Verify:**

```bash
sudo sshd -T | grep -Ei 'permitrootlogin|allowusers|passwordauthentication'
sudo sshd -T -C user=emma,host=charlie,addr=10.20.30.11 | grep -i passwordauthentication   # no
sudo sshd -T -C user=frank,host=charlie,addr=10.20.30.11 | grep -i passwordauthentication  # yes
# From charlie:
ssh -o PubkeyAuthentication=no emma@delta     # Permission denied (publickey,...) — no pw prompt
```

- **`AllowUsers` is a whitelist.** Anyone not listed, including any admin account you normally use, is locked out over SSH. Add it last, after testing, and keep a console open.
- `prohibit-password` means root can log in with a **key only**. That's why the root key copy has to happen first.
- **Wrong permissions break key auth silently.** `~/.ssh` must be `700` and `authorized_keys` `600`. Check `sudo journalctl -u sshd` on delta.

---

**T12 — rsync bwlimit + sftp batch + sha256** *(charlie → delta)*

```bash
sudo rsync -av --delete --bwlimit=500 -e ssh /etc/skel/ root@delta:/tmp/skel_backup/
#     -a = -rlptgoD  (recursive, links, perms, times, group, owner, devices)
#     --bwlimit units = KiB/s
#     trailing slash on /etc/skel/ = copy the CONTENTS, not a skel/ subdirectory

sudo tee /root/sftp_batch.txt > /dev/null <<'EOF'
put /etc/hostname /tmp/
bye
EOF
sudo sftp -b /root/sftp_batch.txt root@delta    # batch mode requires key auth (no prompts)

sha256sum /etc/hostname
sudo ssh root@delta sha256sum /tmp/hostname     # compare the UPLOADED copy, not delta's own /etc/hostname
```

**Verify:**

```bash
sudo ssh root@delta 'ls -la /tmp/skel_backup/'
diff <(sha256sum < /etc/hostname) <(sudo ssh root@delta 'sha256sum < /tmp/hostname') && echo MATCH
```

- **A trailing slash on the source changes the result.** `/etc/skel/` copies the **contents**. `/etc/skel` creates `/tmp/skel_backup/skel/`.
- `--delete` removes destination files that aren't in the source. Test with `-n` (dry run) first.
- `sftp -b` aborts on the first failed command. Prefix a command with `-` (e.g. `-mkdir /tmp/x`) to ignore its errors.

---

### Section 5 — Software Management

**T13 — Two repo files + GPG import** *(charlie)*

```bash
sudo mkdir -p /mnt/rhel10
sudo mount -o ro /dev/sr0 /mnt/rhel10
# Persist it (or the repos break after reboot):
echo '/dev/sr0  /mnt/rhel10  iso9660  ro,nofail  0 0' | sudo tee -a /etc/fstab
# If using an ISO file instead:  /root/rhel10.iso  /mnt/rhel10  iso9660  loop,ro,nofail  0 0
sudo systemctl daemon-reload
ls /mnt/rhel10                       # BaseOS  AppStream  RPM-GPG-KEY-redhat-release ...

sudo rpm --import /mnt/rhel10/RPM-GPG-KEY-redhat-release
```

`/etc/yum.repos.d/lab-baseos.repo`:

```ini
[lab-baseos]
name=Lab RHEL 10 BaseOS
baseurl=file:///mnt/rhel10/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///mnt/rhel10/RPM-GPG-KEY-redhat-release
metadata_expire=1h
priority=10
```

`/etc/yum.repos.d/lab-appstream.repo`:

```ini
[lab-appstream]
name=Lab RHEL 10 AppStream
baseurl=file:///mnt/rhel10/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///mnt/rhel10/RPM-GPG-KEY-redhat-release
metadata_expire=1h
priority=20
```

```bash
sudo dnf clean all
dnf repolist enabled
dnf --disablerepo='*' --enablerepo=lab-baseos list --available | head
# or: dnf repository-packages lab-baseos list --available | head
```

**Verify:**

```bash
rpm -qa gpg-pubkey* --qf '%{NAME}-%{VERSION}  %{SUMMARY}\n'   # Red Hat key present
dnf repoinfo lab-baseos | grep -Ei 'priority|expire|status'
sudo dnf install -y nano               # succeeds without a GPG prompt
```

- **No priorities plugin needed.** `priority=` is built into dnf on RHEL 8+, and RHEL 10 ships dnf 4.20. A lower number means higher priority. The default is 99.
- **`baseurl` needs three slashes:** `file://` plus the absolute path `/mnt/...`.
- **The section header `[lab-baseos]` is the repo ID.** That's what `--enablerepo` and `dnf repolist` show, not the filename.
- If the system is also registered with `subscription-manager`, the CDN repos show up too. That's fine. To see only the lab repos: `sudo subscription-manager config --rhsm.manage_repos=0`.

**Delta needs repos too.** The task only names charlie, but delta has no package source otherwise (Task 2 GUI, Task 21 `nfs-utils`). The DVD is attached to delta as `/dev/sr0`. On delta:

```bash
sudo mkdir -p /mnt/rhel10
echo '/dev/sr0  /mnt/rhel10  iso9660  ro,nofail  0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount /mnt/rhel10
sudo rpm --import /mnt/rhel10/RPM-GPG-KEY-redhat-release
```

Then, from charlie (root SSH works after Task 11; before that, scp asks for delta's root password):

```bash
sudo scp /etc/yum.repos.d/lab-*.repo root@delta:/etc/yum.repos.d/
sudo ssh root@delta dnf repolist
```

The repo files point at `/mnt/rhel10`, so they work unchanged as long as delta uses the same mount point.

---

**T14 — Flatpak** *(charlie)*

```bash
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# --system is the default when run as root; --user would make it per-user
flatpak remotes --show-details          # flathub ... system
flatpak search gedit
sudo flatpak install -y flathub org.gnome.gedit
flatpak list --app
flatpak run org.gnome.gedit             # (only on a GUI session)
sudo flatpak uninstall -y org.gnome.gedit
sudo flatpak uninstall -y --unused      # remove runtimes nothing depends on any more
```

Offline: write those commands into `/root/flatpak_procedure.txt`.

- Use **the same scope throughout**. An app installed `--system` won't show in `flatpak list --user`.
- RHEL 10 may already have a Red Hat `rhel` remote configured (registry.redhat.io), which needs registry login. `flatpak remotes` shows what's there.

---

**T15 — RPM verify / tamper / restore** *(charlie)*

```bash
sudo dnf install -y nano
rpm -q nano                       # record e.g. nano-8.1-3.el10.x86_64
rpm -V nano                       # no output = clean

echo '# lab edit' | sudo tee -a /etc/nanorc
rpm -V nano                       # S.5....T.  c /etc/nanorc
#                                   S=size  5=digest(checksum)  T=mtime  c=config file

# RESTORE: 'dnf reinstall nano' alone does NOT fix it. See note below
sudo mv /etc/nanorc /root/nanorc.modified # (or rm)
sudo dnf reinstall -y nano
rpm -V nano                       # clean again

rpm -qf /etc/hosts                # setup-*
rpm -ql chrony                    # every file in the package
rpm -qc chrony                    # just its config files (bonus)
rpm -qa --last | head             # newest installs first
```

- **Why plain `dnf reinstall` doesn't restore the file:** `/etc/nanorc` is packaged as `%config(noreplace)` (check with `rpm -q --qf '[%{FILEFLAGS:fflags} %{FILENAMES}\n]' nano | grep etc`, which shows `cn`). On reinstall, RPM sees the packaged file is unchanged between "old" and "new", and a modified config file is **left alone** to protect your edits. Remove or move the file first, then reinstall.
- Another way, without reinstalling: `dnf download nano && rpm2cpio nano-*.rpm | cpio -idv ./etc/nanorc` (as your own user, in a scratch directory), then `sudo cp etc/nanorc /etc/nanorc`.
- `rpm -V` flags: `S` size, `M` mode, `5` digest, `D` device, `L` symlink, `U` user, `G` group, `T` mtime, `P` capabilities. A `.` means the test passed.
- `sudo rpm --restore nano` resets **ownership, mode and timestamps only**, not file contents.

---

### Section 6 — Storage

**T16 — GPT partitions with `parted -s`** *(charlie, /dev/vdb)*

```bash
lsblk /dev/vdb                                    # confirm it's the empty 8 GB disk
sudo parted -s /dev/vdb mklabel gpt
sudo parted -s /dev/vdb mkpart charliexfs xfs 1MiB 2049MiB
sudo parted -s /dev/vdb mkpart charlieswap linux-swap 2049MiB 3073MiB
sudo parted -s /dev/vdb mkpart charlielvm 3073MiB 100%
sudo parted -s /dev/vdb set 3 lvm on
sudo parted /dev/vdb align-check optimal 1        # "1 aligned"
sudo partprobe /dev/vdb
```

**Verify:**

```bash
sudo parted -s /dev/vdb unit MiB print            # 3 partitions, flag lvm on #3
lsblk /dev/vdb
```

- **On GPT the first `mkpart` argument is a partition name, not a type.** Write something meaningful (`primary` also works, but it's just a label on GPT).
- **The fs-type argument only sets a type hint.** It doesn't create a filesystem. You still run `mkfs` (Task 17).
- Starting at `1MiB` gives correct alignment. Using `MiB` units, not `MB` (powers of 10), avoids "not aligned" warnings.
- Optional, since the swap partition `vdb2` isn't used by a later task: `sudo mkswap /dev/vdb2`.

---

**T17 — XFS by UUID + VFAT by LABEL** *(charlie)*

```bash
sudo mkfs.xfs -L charlieXFS /dev/vdb1              # XFS labels max 12 chars

sudo dnf install -y dosfstools                     # mkfs.vfat isn't on a minimal install
sudo parted -s /dev/vdc mklabel gpt
sudo parted -s /dev/vdc mkpart usbdata fat32 1MiB 501MiB
sudo partprobe /dev/vdc
sudo mkfs.vfat -n USBDATA /dev/vdc1                # FAT labels: ≤11 chars, stored UPPERCASE

sudo mkdir -p /mnt/charliexfs /mnt/usbdata
sudo blkid /dev/vdb1 /dev/vdc1                     # copy the UUID
```

`/etc/fstab`:

```text
UUID=<uuid-of-vdb1>   /mnt/charliexfs   xfs    defaults               0 0
LABEL=USBDATA         /mnt/usbdata      vfat   noexec,nodev,nosuid    0 0
```

```bash
# tip: get the UUID into fstab without retyping it:
#   echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb1) /mnt/charliexfs xfs defaults 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload     # do this BEFORE mount -a so systemd sees the new fstab
sudo mount -a
sudo findmnt --verify            # catches typos before you reboot
```

**Verify (after reboot):**

```bash
findmnt /mnt/charliexfs; findmnt -no OPTIONS /mnt/usbdata    # rw,nosuid,nodev,noexec,...
lsblk -f /dev/vdb /dev/vdc
```

- **Run `sudo findmnt --verify` (or `sudo mount -a`) before rebooting.** A bad fstab line drops the system into emergency mode at boot.
- **VFAT has no Unix ownership or permissions.** Use the mount options `uid=`, `gid=`, `umask=` if a non-root user needs to write.

---

**T18 — Swap file, priority 20** *(delta)*

```bash
sudo mkdir -p /swap
sudo dd if=/dev/zero of=/swap/extraswap.img bs=1M count=1024 status=progress
# fallocate -l 1G /swap/extraswap.img   ← also fine on XFS/ext4
sudo chmod 0600 /swap/extraswap.img
sudo mkswap /swap/extraswap.img

# SELinux: label the file so the boot-time swapon (systemd swap unit) is allowed to use it
sudo semanage fcontext -a -t swapfile_t '/swap/extraswap\.img'
sudo restorecon -v /swap/extraswap.img

echo '/swap/extraswap.img  none  swap  defaults,pri=20  0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo swapon -a
```

**Verify:**

```bash
swapon --show            # /swap/extraswap.img  file  1024M  0B  20
free -h
ls -lZ /swap/extraswap.img
```

- **`swapon -a` won't touch swap that's already active.** If you activated it manually with the wrong priority, `sudo swapoff /swap/extraswap.img` first, then `sudo swapon -a`.
- **Swap files must not be sparse.** `dd` from `/dev/zero` is always safe. `fallocate` is safe on XFS/ext4. Never use `truncate`, which creates a sparse file.
- **Swap gets used by priority.** Higher priority is used first, and devices with **equal** priority are used round-robin.

---

**T19 — Striped LV + 32 MiB PE** *(charlie)*

```bash
sudo pvcreate /dev/vdb3 /dev/vdd
sudo vgcreate -s 32M vg_lab2 /dev/vdb3 /dev/vdd
sudo lvcreate --type striped -i 2 -L 1G -n lv_stripe vg_lab2     # -i stripes; -I sets stripe size (default 64k)
sudo lvcreate -l 80 -n lv_home2 vg_lab2                     # 80 × 32 MiB = 2.5 GiB

sudo mkfs.ext4 /dev/vg_lab2/lv_stripe
sudo mkfs.xfs  /dev/vg_lab2/lv_home2
sudo mkdir -p /mnt/stripe /mnt/home2
```

`/etc/fstab`:

```text
/dev/mapper/vg_lab2-lv_stripe   /mnt/stripe   ext4   defaults   0 0
/dev/mapper/vg_lab2-lv_home2    /mnt/home2    xfs    defaults   0 0
```

```bash
sudo systemctl daemon-reload && sudo mount -a
```

**Verify:**

```bash
sudo pvs; sudo vgs -o+vg_extent_size
sudo lvs -a -o+devices,segtype,stripes
#  lv_stripe  ... striped  2   /dev/vdb3(0),/dev/vdd(0)
#  lv_home2   ... linear   1   /dev/vdb3(16)
df -hT /mnt/stripe /mnt/home2
```

- **`-L` takes a size; `-l` takes a number of extents** (or `%VG`, `%FREE`). With a 32 MiB PE, `-l 80` = 2.5 GiB.
- **A striped LV needs free extents on as many PVs as it has stripes.** `-i 2` with only one PV with free space fails.
- LVM paths are stable, so `/dev/mapper/...` in fstab is fine. Using the filesystem UUID is also correct.

---

**T20 — `pvmove`, `vgreduce`, extend to 100% FREE** *(charlie)*

**Why a plain `pvmove /dev/vdd` fails:** the stripes of `lv_stripe` must sit on **different** PVs under the default `normal` allocation policy. Once vdd is excluded, the only PV left is vdb3, which already holds the other stripe. LVM reports *"Insufficient suitable allocatable extents"*. `--alloc anywhere` lifts the "parallel areas on separate PVs" rule.

```bash
sudo pvs -o+pv_used                          # vdd has the 16 extents of lv_stripe's 2nd stripe
sudo pvmove /dev/vdd                         # fails, as described above
sudo pvmove --alloc anywhere /dev/vdd        # moves that stripe onto vdb3
sudo vgreduce vg_lab2 /dev/vdd
sudo pvremove /dev/vdd
sudo wipefs -a /dev/vdd                      # clear any remaining signatures
sudo lvextend -l +100%FREE -r /dev/vg_lab2/lv_home2   # -r = resize the fs too (xfs_growfs, online)
```

**Verify:**

```bash
df -h /mnt/home2                             # grown
sudo lvs -a -o+devices,segtype,stripes
#  lv_stripe  ... striped  2   /dev/vdb3(..),/dev/vdb3(..)   ← both stripes now on ONE PV
sudo vgs vg_lab2                             # #PV 1, VFree 0
lsblk /dev/vdd; sudo wipefs /dev/vdd         # no signatures
```

- **What happened to `lv_stripe`:** it **still reports segment type `striped`** with 2 stripes, but both stripes now live on `/dev/vdb3`. The layout is "striped" in name only: no performance gain, and no protection either way. To make it truly linear you'd need a conversion such as `sudo lvconvert --type linear` (only some segment types support it) or recreating the LV.
- **Shrinking:** XFS can't shrink. The single-command grow is `lvextend -r` (or `lvresize -r`). Without `-r` you'd have to run `sudo xfs_growfs /mnt/home2` yourself.
- `pvmove` is safe to interrupt. Run `sudo pvmove` with no arguments to resume an interrupted move.

---

### Section 7 — File Systems & NFS

**T21 — NFSv4-only server** *(delta)()*

```bash
sudo dnf install -y nfs-utils    # needs delta's repos (T13 delta note)
sudo vim /etc/nfs.conf
#   [nfsd]
#   vers3=n
#   vers4=y
#   vers4.2=y       # (vers4.0 / vers4.1 may stay at their defaults)

sudo mkdir -p /srv/nfs/projects /srv/nfs/archive
sudo chmod 777 /srv/nfs/projects # see root_squash note — lets charlie's root create files

sudo tee -a /etc/exports > /dev/null <<'EOF'
/srv/nfs/projects  10.20.30.0/24(rw,sync,sec=sys,no_subtree_check)
/srv/nfs/archive   charlie.ex200.lab(ro,sync,sec=sys,root_squash)
EOF

sudo firewall-cmd --permanent --add-service=nfs     # v4 only needs 2049/tcp — no rpc-bind/mountd
sudo firewall-cmd --reload
sudo systemctl enable --now nfs-server
sudo exportfs -rav
```

**Verify:**

```bash
sudo exportfs -v
sudo cat /proc/fs/nfsd/versions   # -3 +4 +4.1 +4.2
showmount -e localhost            # may work or fail on a v4-only server — see note
sudo mount -t nfs4 delta.ex200.lab:/srv/nfs/projects /mnt && sudo umount /mnt   # real proof — NOT localhost (127.0.0.1 is outside 10.20.30.0/24)
```

- **`showmount` may fail here.** It uses the NFSv3 **MOUNT** protocol through rpcbind. With `vers3=n`, `rpc.mountd` stops advertising MOUNT v3, so `showmount -e` can fail with *"Program not registered"*. If it still lists the exports (rpcbind/mountd still answering), that's fine too; `/proc/fs/nfsd/versions` showing `-3` is the real proof v3 is off. Use `sudo exportfs -v` and an actual `nfs4` test mount instead.
- **`root_squash` is the default on every export.** charlie's root becomes `nobody` on the server. The task expects root on charlie to **create** a file in projects (Task 22 step 4), so the export directory must be writable by `nobody` (`sudo chmod 777`, or `sudo chown nobody:nobody`), or the export needs `no_root_squash`. Pick one; `chmod 777` is the least invasive.
- `charlie.ex200.lab` in the exports file must resolve on delta, which the `/etc/hosts` entries from Task 4 take care of.
- `exportfs -r` re-reads `/etc/exports` without restarting the server.

---

**T22 — NFS client with `_netdev,nofail`** *(charlie)*

```bash
sudo dnf install -y nfs-utils
sudo mkdir -p /mnt/projects /mnt/archive
```

`/etc/fstab`:

```text
delta:/srv/nfs/projects  /mnt/projects  nfs4  rw,_netdev,nofail  0 0
delta:/srv/nfs/archive   /mnt/archive   nfs4  ro,_netdev,nofail  0 0
```

```bash
sudo systemctl daemon-reload && sudo mount -a
sudo touch /mnt/projects/root_test && echo "projects RW OK" # owned by nobody (root_squash)
sudo touch /mnt/archive/root_test                            # Read-only file system
```

**Verify:**

```bash
findmnt -t nfs4                     # both mounted, vers=4.2
nfsstat -m
ls -l /mnt/projects/root_test       # nobody nobody
```

- **`_netdev`** tells systemd to wait for the network before mounting. **`nofail`** means the boot doesn't hang or drop to emergency mode if delta is down.
- **Old-style `host:/path` source.** NFSv4 still accepts the full server path, so use the same path as in `/etc/exports`.
- `fstype nfs` with `vers=4.2` and `fstype nfs4` both work. The task says `nfs4`.

---

**T23 — AutoFS wildcard indirect map** *(delta then charlie)*

delta:

```bash
sudo mkdir -p /srv/nfs/homes/emma
sudo chown 2100:6000 /srv/nfs/homes/emma && sudo chmod 700 /srv/nfs/homes/emma
echo '/srv/nfs/homes  10.20.30.0/24(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports
sudo exportfs -rav
```

charlie:

```bash
sudo dnf install -y autofs

# RHEL's default /etc/auto.master has an ACTIVE line:   /net  -hosts
# That already claims /net, so /net/homes would be treated as an NFS server called "homes".
# Comment it out:
sudo sed -i 's|^/net|#/net|' /etc/auto.master
```

`/etc/auto.master.d/labhome.autofs`:

```text
/net/homes  /etc/auto.labhome  --timeout=60 --ghost
```

`/etc/auto.labhome`:

```text
*  -fstype=nfs4,rw  delta.ex200.lab:/srv/nfs/homes/&
```

```bash
sudo systemctl enable --now autofs
su - emma
ls /net/homes/emma          # triggers the mount
exit
mount | grep /net/homes     # delta.ex200.lab:/srv/nfs/homes/emma on /net/homes/emma
sleep 75; mount | grep /net/homes   # gone after the 60s idle timeout
```

- **`*` and `&` do the wildcard work.** `*` matches any key (the directory name being accessed) and `&` substitutes that key into the source path.
- **`--ghost` does nothing for a `*` map.** Browse mode only pre-creates directories for **explicit** keys, and a wildcard has none. You won't see `/net/homes/emma` in `ls /net/homes` until it's accessed. That's expected, not a fault.
- **Don't create `/net/homes` yourself.** autofs creates and owns its mount points.
- `--timeout=60` is in seconds. The `/etc/autofs.conf` default is 300.
- Debug with `systemctl status autofs` and `sudo journalctl -u autofs`, or stop the service and run `sudo automount -f -v` in the foreground.

---

**T24 — Permission repair** *(charlie)*

> **Setup** (no lab script creates the broken state, so build it first):
>
> ```bash
> sudo mkdir -p /opt/finance/{reports,bin,private}
> printf '#!/bin/bash\necho report\n' | sudo tee /opt/finance/bin/run_report.sh > /dev/null
> sudo chmod 000 /opt/finance
> ```

```bash
sudo chown gina:ops /opt/finance
sudo chmod 2750 /opt/finance

sudo chgrp ops /opt/finance/reports
sudo chmod 2770 /opt/finance/reports     # 'g+s' is the required part; 2770 is a sensible full mode

sudo chown gina /opt/finance/bin/run_report.sh
sudo chmod 4754 /opt/finance/bin/run_report.sh

sudo groupadd gina                       # gina was created with -g ops, so no "gina" group exists yet
sudo chown gina:gina /opt/finance/private
sudo chmod 0700 /opt/finance/private

find /usr/bin -type f -perm -4000 | sudo tee /root/suid_list.txt > /dev/null
```

**Verify:**

```bash
sudo stat -c '%A %a %U:%G %n' /opt/finance /opt/finance/reports /opt/finance/bin/run_report.sh /opt/finance/private
#  drwxr-s--- 2750 gina:ops   /opt/finance
#  drwxrws--- 2770 root:ops   /opt/finance/reports      (chgrp only; owner unspecified)
#  -rwsr-xr-- 4754 gina:root  /opt/finance/bin/run_report.sh   (chown owner only; group unspecified)
#  drwx------ 700  gina:gina  /opt/finance/private
sudo cat /root/suid_list.txt             # passwd, sudo, su, mount, chage, ...
```

- **`-perm -4000` vs `-perm /4000`:** `-4000` means "at least these bits". `/4000` means "any of these bits", which is the same thing for a single bit.
- **`chown: invalid group: 'gina:gina'`:** `useradd -g ops` sets the primary group and skips creating a private `gina` group. Run `sudo groupadd gina` and leave gina's primary group as `ops`, which other tasks depend on.
- **Order matters: `chown` clears SUID/SGID** on files. Do `chown` first and `chmod 4754` second.
- **Setuid does nothing on scripts.** The Linux kernel ignores the setuid bit on shebang scripts, so `4754` on `run_report.sh` sets the bit correctly but won't actually elevate privilege at exec time.
- **SGID on a directory** makes new files inherit the directory's group. The capital `S` in `ls` output means SGID is set but group-execute isn't.

---

### Section 8 — Services, Logging & Time

**T25 — Chrony server + client**

delta (`/etc/chrony.conf`, then):

```text
allow 10.20.30.0/24
local stratum 10        # serve time even if delta has no upstream (isolated lab)
```

```bash
sudo systemctl enable --now chronyd && sudo systemctl restart chronyd
sudo firewall-cmd --permanent --add-service=ntp && sudo firewall-cmd --reload
sudo timedatectl set-timezone Asia/Tokyo
```

charlie (`/etc/chrony.conf`):

```text
#pool 2.rhel.pool.ntp.org iburst      ← comment out every pool/server line
#sourcedir /run/chrony-dhcp           ← and DHCP-provided servers, so delta is the ONLY source
server delta.ex200.lab iburst
```

```bash
sudo systemctl restart chronyd
sudo timedatectl set-timezone Europe/London
```

**Verify (charlie):**

```bash
chronyc sources -v          # ^* delta.ex200.lab  (^+ / ^- acceptable; ^? = unreachable)
chronyc tracking
timedatectl                 # Time zone: Europe/London; NTP service: active
# on delta:
sudo chronyc clients        # charlie listed
```

- **Without `local stratum 10`, delta may refuse to serve.** In an isolated lab delta can't reach the internet, so it isn't synchronised itself and its clients see it as `^?` or `^x`. `local stratum 10` makes it serve its own clock.
- **`^*` is not instant.** `iburst` speeds up the first sync, but give it 30–60 seconds.
- Timezone names come from `timedatectl list-timezones`.

---

**T26 — Custom tuned profile** *(charlie)*

```bash
sudo dnf install -y tuned
sudo systemctl enable --now tuned
sudo mkdir -p /etc/tuned/profiles/lab-highio
```

`/etc/tuned/profiles/lab-highio/tuned.conf`:

```ini
[main]
summary=Lab high-IO profile based on throughput-performance
include=throughput-performance

[sysctl]
vm.dirty_ratio=40
vm.swappiness=10

[cpu]
governor=performance
```

```bash
tuned-adm list | grep lab-highio
sudo tuned-adm profile lab-highio
```

**Verify:**

```bash
tuned-adm active            # Current active profile: lab-highio
sudo tuned-adm verify       # "Verification succeeded" (cpu governor may warn inside a VM)
sysctl vm.swappiness vm.dirty_ratio     # 10 / 40
cat /etc/tuned/active_profile           # persists across reboot via this file
```

- **Where custom profiles live:** tuned 2.23+ (RHEL 10 ships 2.27) reads them from **`/etc/tuned/profiles/<name>/`**. Older RHEL used `/etc/tuned/<name>/`, which still works as a fallback.
- **Child values override parent values.** Settings in your file win over the same keys from `include=`d profiles.
- **The governor may not apply in a VM.** Most VMs expose no `cpufreq`, so the `[cpu]` governor is skipped. That's harmless.
- **Don't also set these in `/etc/sysctl.d/`.** tuned applies its values at startup and can conflict with your file.

---

**T27 — Process management** *(charlie)*

```bash
openssl speed -multi 2 &> /dev/null &
dd if=/dev/zero of=/dev/shm/memtest bs=1M count=800      # fills 800 MiB of RAM-backed tmpfs
# or: stress-ng --vm 1 --vm-bytes 800M --timeout 60s &
free -h                                  # 'shared' and 'buff/cache' jump by ~800M
rm -f /dev/shm/memtest                   # the tmpfs file stays in RAM after dd exits; free it

ps -eo pid,ppid,ni,pcpu,pmem,comm --sort=-pcpu | head -5   # top CPU consumers
# (memory: --sort=-pmem  or  top, then 'M')

renice -n 19 -p <pid>                    # default nice is 0 → 19 (lowest priority)
ps -o pid,ni,comm -p <pid>
# Starting a process at a given nice level: nice -n 19 CMD

sudo systemd-run --scope -p CPUQuota=20% stress-ng --cpu 1 --timeout 60s &
# or with no stress-ng:  sudo systemd-run --scope -p CPUQuota=20% sha1sum /dev/zero &
top                                      # that process stays at ~20% CPU

sudo pkill -f stress-ng
pkill -f 'openssl speed'                 # -f matches the full command line
pgrep -af 'stress-ng|openssl speed'      # nothing left
```

**Step 7, SIGHUP:** see note. Use `sshd`, which reloads its config on SIGHUP:

```bash
sudo kill -HUP "$(cat /run/sshd.pid)"      # or: sudo pkill -HUP -x sshd  /  sudo systemctl reload sshd
sudo journalctl -u sshd -n 5             # "Received SIGHUP; restarting."
```

- **Don't send SIGHUP to chronyd.** It treats SIGHUP like SIGTERM: it **exits** (journal: `chronyd exiting`) instead of re-reading `/etc/chrony.conf`. If you already did it, `sudo systemctl start chronyd`. Daemons that do reload on HUP: `sshd`, `rsyslogd` (reopens log files), `httpd` (graceful restart via `systemctl reload`).
- **Only root can lower a nice value** (raise priority). Regular users can only raise it.
- **Use a precise pattern with `pkill -f`.** `pkill -f openssl` also kills anything else whose command line mentions "openssl". Check first with `pgrep -af PATTERN`.
- `kill` sends SIGTERM (15) by default. Use `-9` (SIGKILL) only when a process ignores TERM.
- **Persistent CPU limits** go on a unit: `sudo systemctl set-property httpd.service CPUQuota=20%`.

---

**T28 — Persistent journal + rsyslog + logrotate** *(charlie)*

RHEL 10 has no `/etc/systemd/journald.conf` by default (defaults live in `/usr/lib/systemd/journald.conf`), so use a drop-in:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/lab.conf > /dev/null <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
ForwardToSyslog=yes
EOF
# If you're working as an ops member via sudo, T10's 0027 umask gives 750/640 here.
# Restore the standard /etc permissions so non-root tools can read the drop-in:
sudo chmod 755 /etc/systemd/journald.conf.d
sudo chmod 644 /etc/systemd/journald.conf.d/lab.conf
sudo systemctl restart systemd-journald
sudo journalctl --flush               # switch from /run/log/journal to disk now; creates /var/log/journal
```

`/etc/rsyslog.d/secure-lab.conf`:

```text
authpriv.*    /var/log/secure.lab
```

```bash
sudo rsyslogd -N1                     # syntax check
sudo systemctl restart rsyslog
```

`/etc/logrotate.d/secure.lab`:

```text
/var/log/secure.lab {
    weekly
    rotate 8
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
    endscript
}
```

```bash
sudo logrotate -d /etc/logrotate.d/secure.lab    # dry-run/debug, no changes made

# Test: failed sudo as frank
sudo -u frank sudo -k /usr/bin/systemctl restart httpd   # type a WRONG password at frank's prompt
sudo journalctl _COMM=sudo -n 5        # "incorrect password attempt"
sudo tail /var/log/secure.lab

sudo journalctl --vacuum-time=7d
```

**Verify:**

```bash
ls /var/log/journal/                  # machine-id directory exists
sudo journalctl --disk-usage
sudo journalctl --list-boots          # more than one boot listed after a reboot
systemd-analyze cat-config systemd/journald.conf | grep -E 'Storage|SystemMaxUse|ForwardToSyslog'
```

- **`ForwardToSyslog` isn't how RHEL's rsyslog gets journal entries.** RHEL's rsyslog reads the journal **directly** with the `imjournal` module, so `/var/log/secure` etc. fill up even with `ForwardToSyslog=no`. The task asks for forwarding, so set it, but it's not why `secure.lab` gets entries.
- **`postrotate` HUPs rsyslog** so it reopens the new file. Without it, rsyslog keeps writing to the rotated file. The stock `/etc/logrotate.d/rsyslog` does the same thing.
- **`/var/log/journal` doesn't appear on restart alone.** `Storage=persistent` creates it, but only when journald moves from `/run` to `/var`. That happens at boot via `systemd-journal-flush.service`, or right away with `sudo journalctl --flush`. Restarting journald by itself often keeps it writing to `/run/log/journal`. The manual method is `sudo mkdir /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal`.
- Other ways to match the sudo entries: `sudo journalctl -t sudo`, `sudo journalctl SYSLOG_FACILITY=10` (authpriv).

---

**T29 — at + cron + systemd timer** *(charlie)*

```bash
# at
sudo dnf install -y at && sudo systemctl enable --now atd
echo 'echo "at-fired $(date)" >> /var/log/at_lab.log' | sudo at now + 3 minutes
sudo atq                                  # job queued
# (single quotes: $(date) is evaluated when the job RUNS, not when you schedule it)

# cron for emma
sudo crontab -e -u emma
#   15 7 * * 1-5  df -h > ~/disk_report.log
sudo crontab -l -u emma
```

`/usr/local/bin/labhealth.sh`:

```bash
#!/bin/bash
{
  echo "=== $(date) ==="
  uptime
  free -m
  df -h /
} >> /var/log/labhealth.log
```

`/etc/systemd/system/labhealth.service`:

```ini
[Unit]
Description=Lab health snapshot

[Service]
Type=oneshot
ExecStart=/usr/local/bin/labhealth.sh
```

`/etc/systemd/system/labhealth.timer`:

```ini
[Unit]
Description=Run labhealth every 3 hours

[Timer]
OnCalendar=*-*-* 00/3:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo chmod 755 /usr/local/bin/labhealth.sh
sudo systemctl daemon-reload
sudo systemctl enable --now labhealth.timer    # enable the TIMER, not the service
sudo systemctl start labhealth.service    # test run now
```

**Verify:**

```bash
systemctl list-timers --all | grep labhealth
systemd-analyze calendar '*-*-* 00/3:00:00'    # next elapse: next multiple of 3h
cat /var/log/labhealth.log
systemctl status labhealth.service             # inactive (dead), status=0/SUCCESS
```

- **`OnCalendar` format is `[DayOfWeek] Year-Month-Day Hour:Minute:Second`.** `*-*-*` = any year, any month, any day (every day); `*` is a wildcard as in cron. Other examples: `Mon *-*-* 09:00:00` (Mondays 09:00), `*-*-01 00:00:00` (1st of each month), `*-*-* *:00/15:00` (every 15 min).
- **Looking it up in the exam:** `man systemd.time`, then search `/CALENDAR EVENTS` for the syntax and examples. Test any expression with `systemd-analyze calendar '<expr>' --iterations=4`, which prints the normalized form and the next 4 run times.
- **`00/3` means start at 00 and repeat every 3 hours:** 00, 03, 06, … 21. `OnUnitActiveSec=3h` is a relative alternative, but `OnCalendar` + `Persistent=true` is what the task wants.
- **`Persistent=true`** runs a missed job at the next boot if the system was off when it was due. It only works with `OnCalendar`.
- **Cron fields:** `minute hour day-of-month month day-of-week`. `1-5` = Mon–Fri.
- In cron, `~` works because cron runs commands with `/bin/sh` and sets `HOME`. `%` is special in crontab lines; escape it as `\%`.

---

### Section 9 — Scripting

**T30 — `svcctl.sh` with `case`**

`/usr/local/bin/svcctl.sh`:

```bash
#!/bin/bash
# Usage: svcctl.sh <start|stop|restart|status|check> <service>

usage() { echo "Usage: $(basename "$0") <start|stop|restart|status|check> <service>" >&2; }

if [[ $# -ne 2 ]]; then
    usage
    exit 2
fi

action=$1
svc=$2

case "$action" in
    start|stop|restart|status|check) ;;     # valid; fall through to the service check
    *) usage; exit 2 ;;
esac

if ! systemctl cat "$svc" &>/dev/null; then
    echo "Unknown service" >&2
    exit 3
fi

case "$action" in
    start|stop|restart)
        systemctl "$action" "$svc"
        exit $?
        ;;
    status)
        systemctl status "$svc" --no-pager
        exit $?
        ;;
    check)
        if systemctl is-active --quiet "$svc"; then
            echo "RUNNING"; exit 0
        else
            echo "STOPPED"; exit 1
        fi
        ;;
esac
```

```bash
sudo chmod 755 /usr/local/bin/svcctl.sh
svcctl.sh check sshd; echo $?           # RUNNING 0
svcctl.sh bogus sshd; echo $?           # usage on stderr, 2
svcctl.sh check nosuchsvc; echo $?      # Unknown service, 3
svcctl.sh check 2>/dev/null; echo $?    # wrong arg count → 2
bash -x /usr/local/bin/svcctl.sh check chronyd
```

- **The exit code is whatever the last command returned.** `exit $?` after `systemctl` passes its code through. `systemctl status` returns 3 for an inactive unit, which is correct behaviour.
- **Send errors to stderr with `>&2`.** The test is `svcctl.sh bogus x 2>/dev/null` printing nothing.
- **Pick an order and be consistent.** The task doesn't say whether to validate the action or the service first. Checking the action first avoids calling `systemctl` with junk.

---

**T31 — CSV `while read` user creation**

```bash
sudo tee /root/newusers.csv > /dev/null <<'EOF'
# username,uid,gid,fullname
ivan,2200,6000,Ivan Petrov
julia,2201,6000,Julia Kim

kai,2202,6001,Kai Nguyen
EOF
```

`/usr/local/bin/csv_users.sh`:

```bash
#!/bin/bash
infile=/root/newusers.csv
pwfile=/root/passwords.txt

[[ -r $infile ]] || { echo "Cannot read $infile" >&2; exit 1; }

touch "$pwfile"
chmod 0600 "$pwfile"

while IFS=, read -r username uid gid fullname || [[ -n $username ]]; do
    [[ -z $username || $username == \#* ]] && continue      # skip blank + comment lines

    if id "$username" &>/dev/null; then
        echo "Skipping $username: already exists" >&2
        continue
    fi

    useradd -u "$uid" -g "$gid" -c "$fullname" -m "$username" || continue
    password=$(openssl rand -base64 12)
    echo "${username}:${password}" | chpasswd
    echo "${username},${password}" >> "$pwfile"
done < "$infile"
```

```bash
sudo chmod 700 /usr/local/bin/csv_users.sh
sudo /usr/local/bin/csv_users.sh
getent passwd ivan julia kai
sudo ls -l /root/passwords.txt; sudo cat /root/passwords.txt
```

- **`IFS=,` applies only to the `read`,** and the last variable (`fullname`) absorbs the rest of the line, spaces included.
- **`-r` stops `read` from treating backslashes as escapes.**
- **`|| [[ -n $username ]]` handles a missing final newline.** Without it, a last line with no trailing newline is silently skipped.
- **`== \#*` inside `[[ ]]` is a glob match** ("starts with #"). The `#` has to be escaped or quoted.
- **`< "$infile"` after `done` feeds the loop directly.** Avoid `cat file | while read`, which runs the loop in a subshell.
- **Create the passwords file first.** `touch` + `chmod 600` before writing means there's never a moment when passwords are world-readable.
- `openssl rand -base64 12` gives a 16-character password: 12 random bytes, base64-encoded.

---

**T32 — Health report + trap + rotation cron**

`/root/health_report.sh`:

```bash
#!/bin/bash
set -euo pipefail

outdir=/var/log/health
tmp=/tmp/health.$$.tmp
final="$outdir/$(hostname)-$(date +%F).log"

trap 'rm -f "$tmp"' EXIT          # always clean up the temp file
trap 'exit 1' INT TERM HUP        # on interrupt, exit → fires the EXIT trap

mkdir -p "$outdir"

{
    echo "=== Health report: $(date) ==="
    echo "Hostname: $(hostname)"
    echo "Kernel:   $(uname -r)"
    echo "Uptime:   $(uptime -p)"
    echo "Load:     $(cut -d' ' -f1-3 /proc/loadavg)"
    echo
    echo "--- Top 5 CPU processes ---"
    ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -6
    echo
    echo "--- Disk usage ---"
    df -hT -x tmpfs -x devtmpfs
    echo
    echo "--- Failed systemd units ---"
    systemctl --failed --no-legend --no-pager || true
} > "$tmp"

mv -f "$tmp" "$final"             # atomic within one filesystem; else copy + rename
chmod 640 "$final"

# Rotation: keep only the 14 newest reports
ls -1t "$outdir"/*.log 2>/dev/null | tail -n +15 | xargs -r rm -f
```

```bash
sudo chmod 700 /root/health_report.sh
sudo /root/health_report.sh && ls -l /var/log/health/
sudo crontab -e     # root's crontab:
#   0 6 2-31 * *  /root/health_report.sh
sudo crontab -l
```

- **Cron has no "except" operator,** so `2-31` in day-of-month = every day except the 1st.
- **Watch out for day-of-month plus day-of-week together.** If **both** fields are restricted (not `*`), cron runs when **either** matches. Leave day-of-week as `*` here.
- **Why `mv` to `/var/log` isn't truly atomic:** `/tmp` and `/var/log` may be different filesystems, and then `mv` copies and deletes. The task specifies `/tmp`. For a truly atomic rename, create the temp file in the destination directory (`mktemp -p "$outdir"`).
- **One `trap` on EXIT covers normal exit,** `set -e` failures, and (through the INT/TERM handler) Ctrl-C.
- **Another way to rotate:** `find "$outdir" -name '*.log' -mtime +13 -delete`. This rotates by age, so it isn't the same as "keep 14 files" if a day is skipped.

---

### Section 10 — SELinux

**T33 — Custom web root** *(charlie)*

```bash
getenforce
grep ^SELINUX= /etc/selinux/config     # must be SELINUX=enforcing
# if not: set it in /etc/selinux/config (persistent) AND run: sudo setenforce 1 (now)

sudo dnf install -y httpd
sudo systemctl enable --now httpd
sudo firewall-cmd --permanent --zone=labzone --add-service=http && sudo firewall-cmd --reload  # for remote tests

sudo mkdir -p /srv/websites/site1
echo "Site1 charlie" | sudo tee /srv/websites/site1/index.html
```

`/etc/httpd/conf.d/site1.conf`:

```apache
DocumentRoot "/srv/websites/site1"
<Directory "/srv/websites/site1">
    AllowOverride None
    Require all granted
</Directory>
```

```bash
sudo apachectl configtest              # Syntax OK
sudo systemctl restart httpd
curl -I http://localhost/                    # HTTP/1.1 403 Forbidden
curl http://localhost/index.html             # plain 403: the LocationMatch only covers "/"
            # 403 Forbidden
ls -Zd /srv/websites/site1             # var_t (or default_t) → wrong label

# Diagnose
sudo journalctl -u httpd -n 20
sudo tail /var/log/httpd/error_log     # "Permission denied: ... access to /index.html denied"
sudo ausearch -m AVC -ts recent        # denied { getattr/read } ... scontext=httpd_t tcontext=var_t
sudo sealert -a /var/log/audit/audit.log    # (setroubleshoot-server) plain-English fix suggestion

# Fix (persistent rule + apply it)
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/websites(/.*)?'
sudo restorecon -Rv /srv/websites
curl http://localhost/                 # Site1 charlie
ps -eZ | grep httpd                    # system_u:system_r:httpd_t:s0
```

**Verify:**

```bash
sudo semanage fcontext -l -C           # your local customisation listed
ls -Zd /srv/websites /srv/websites/site1/index.html   # httpd_sys_content_t
```

- **`chcon` doesn't survive a relabel.** A relabel or `restorecon` reverts it. `semanage fcontext` + `restorecon` is the persistent answer.
- **The regex `'(/.*)?'` matches the directory itself and everything below it.** Quote it so the shell doesn't expand it.
- **A `Require all granted` block is needed for any directory outside `/var/www`.** The stock `httpd.conf` denies access to `/` by default, so a missing block is a second, non-SELinux cause of 403. Check the `error_log` to tell them apart: an AVC means SELinux, "client denied by server configuration" means Apache config.
- **httpd starts fine and returns 403.** It doesn't fail to start. SELinux only blocks the file reads.

---

**T34 — Non-standard SSH port + booleans** *(charlie)*

`/etc/ssh/sshd_config.d/20-ports.conf`:

```text
Port 22
Port 2222
```

```bash
sudo dnf install -y policycoreutils-python-utils # provides semanage (if not present)
sudo semanage port -a -t ssh_port_t -p tcp 2222
sudo semanage port -l | grep ssh_port_t           # ssh_port_t  tcp  2222, 22

sudo firewall-cmd --permanent --zone=labzone --add-port=2222/tcp
sudo firewall-cmd --reload

sudo sshd -t && sudo systemctl restart sshd
sudo ss -tlnp | grep sshd                         # 0.0.0.0:22 and 0.0.0.0:2222

getsebool -a | grep -E 'ssh_sysadm_login|use_nfs_home_dirs'
sudo setsebool -P ssh_sysadm_login on             # fall back to use_nfs_home_dirs if absent
sudo setsebool -P httpd_can_network_connect_db on
getsebool ssh_sysadm_login httpd_can_network_connect_db
sudo semanage boolean -l -C                       # shows locally-changed (persistent) booleans
```

Step 7, file context:

```bash
sudo cp /etc/motd /var/www/html/motd.txt
ls -Z /var/www/html/motd.txt          # httpd_sys_content_t already — see note
# To actually reproduce the wrong label, preserve the source context:
sudo cp --preserve=context /etc/motd /var/www/html/motd.txt     # or: cp -a, or mv
ls -Z /var/www/html/motd.txt          # etc_t
sudo restorecon -v /var/www/html/motd.txt  # → httpd_sys_content_t
```

**Verify:**

```bash
ssh -p 2222 localhost true && echo "2222 OK"
sudo firewall-cmd --zone=labzone --list-ports # 9000-9010/tcp 2222/tcp
ls -Z /var/www/html/motd.txt
```

- **List `Port 22` too.** Once any `Port` line exists, sshd stops listening on the default 22. Both lines are needed.
- **Missing the SELinux port label breaks sshd's bind.** sshd fails to bind 2222 (`error: Bind to port 2222 ... failed: Permission denied`) and AVCs show up in `ausearch -m AVC`.
- **`setsebool` without `-P` only lasts until reboot.**
- **Why the task's "observe `etc_t`" doesn't happen with plain `cp`:** `cp` **creates a new file**, which takes the label of its parent directory (`httpd_sys_content_t` in `/var/www/html`). `mv`, `cp -a` and `cp --preserve=context` keep the **source** label (`etc_t`, or `admin_home_t` if the file was created in `/root`). That's the classic way web content ends up mislabeled. The fix in every case is `restorecon`.

---

### Section 11 — Essential Tools

**T35 — grep, redirection, su -, xz archive**

```bash
# 1. Anchored: field 3 (UID) must be exactly 2100-2103
grep -E '^[^:]+:[^:]*:210[0-3]:' /etc/passwd | sudo tee /root/exam_users.txt > /dev/null
# 2. tee -a appends (like >>); plain tee truncates (like >)
date | sudo tee -a /root/exam_users.txt > /dev/null
# 3. -v inverts: drop comment lines (optionally indented) and empty lines
sudo grep -Ev '^[[:space:]]*(#|$)' /etc/ssh/sshd_config | sudo tee /root/sshd_active.txt > /dev/null
# 4. su - = login shell: emma's HOME, PATH and cwd (/srv/users/emma)
su - emma
find /etc -name '*.conf' > ~/conf_list.txt 2> ~/conf_errors.txt
ls -l ~/conf_*.txt
exit
# 5-6. -J = xz; name the member to extract just that file
sudo tar -cJf /root/sshconf.tar.xz /etc/ssh
sudo tar -tJf /root/sshconf.tar.xz | grep sshd_config
sudo mkdir -p /root/restore
sudo tar -xJf /root/sshconf.tar.xz -C /root/restore etc/ssh/sshd_config
```

**Verify:**

```bash
sudo cat /root/exam_users.txt                  # 4 user lines + a date line
sudo grep -c '' /root/sshd_active.txt; sudo grep -E '^\s*#' /root/sshd_active.txt    # no output from 2nd cmd
sudo ls -l /srv/users/emma/conf_list.txt /srv/users/emma/conf_errors.txt  # owned by emma
sudo ls -l /root/restore/etc/ssh/sshd_config
```

- **In a root shell, steps 1–3 are plain `>` and `>>`.** That's the redirection skill this task grades: `grep ... > /root/exam_users.txt`, `date >> /root/exam_users.txt`. The `| sudo tee` form above is only needed because `/root` isn't writable by your own user.
- **Anchor on the field separators.** `grep -E '210[0-3]'` without anchors also matches a GID or a home path containing `2100`.
- **Use `su -`, not plain `su`.** Plain `su emma` keeps root's environment and working directory, so `~` may not expand to emma's home.
- **The member name has no leading slash** (`etc/ssh/sshd_config`) because `tar` stripped it at creation.
- **Extract the file into `/root/restore/etc/ssh/sshd_config`.** To drop it directly into `/root/restore/`, add `--strip-components=2`.
- **The task says "nothing may print", so it needs two separate redirections.** `&>` sends both streams to one file. Here stdout and stderr go to **different** files.

**tar options reference**

Pattern: `tar -<mode><compression><other>f ARCHIVE [paths]`. Pick one mode, add a compression letter if you need one, and put `f` **last** in the bundle, because the next word is the archive name.

| Option | Long form | Meaning |
|---|---|---|
| `-c` | `--create` | create an archive (mode) |
| `-x` | `--extract` | extract (mode) |
| `-t` | `--list` | list contents (mode) |
| `-r` | `--append` | add files to an existing **uncompressed** archive (mode) |
| `-f FILE` | `--file` | archive filename; always lowercase, always followed by the name |
| `-z` | `--gzip` | gzip → `.tar.gz` / `.tgz` |
| `-j` | `--bzip2` | bzip2 → `.tar.bz2` |
| `-J` | `--xz` | xz → `.tar.xz` (capital J) |
| `-a` | `--auto-compress` | pick compression from the archive suffix (with `-c`) |
| `-v` | `--verbose` | print each file as it's processed |
| `-C DIR` | `--directory` | change to DIR first; the directory must already exist |
| `-p` | `--preserve-permissions` | keep permissions on extract (default when root) |
| | `--strip-components=N` | drop the first N path parts on extract |
| | `--selinux` / `--acls` / `--xattrs` | store/restore SELinux contexts, ACLs, xattrs |
| | `--exclude=PATTERN` | skip matching files when creating |

```bash
tar -cvJf /root/a.tar.xz /etc/ssh           # create, xz
tar -tvJf /root/a.tar.xz                    # list (on extract/list, modern tar auto-detects compression, so -J is optional)
tar -xJf  /root/a.tar.xz -C /root/restore   # extract everything into /root/restore
tar -xJf  /root/a.tar.xz -C /root/restore etc/ssh/sshd_config   # one member, no leading /
```

- **Case matters.** `-F` (capital) is `--info-script` and turns on multi-volume mode, which gives "Cannot use multi-volume compressed archives". `-J` is xz but `-j` is bzip2.
- **`tar` strips the leading `/` when creating**, so members are `etc/ssh/...`. Use exactly what `tar -tf` shows when extracting a single file.
- **Looking it up in the exam:** `tar --help | less` is quicker than `man tar` and lists every short option. `man tar` has an EXAMPLES section.

---

## 🔑 Key Commands Quick Reference (Exam #2 focus)

### Boot / Recovery

    # init=/bin/bash method
    # Boot GRUB -> 'e' -> replace ro with rw -> append init=/bin/bash -> Ctrl-x
    # (already root in this shell, no sudo)
    mount -o remount,rw /
    passwd
    touch /.autorelabel
    exec /sbin/init          # graceful, or sync; reboot -f

### Parted (scripted)

    sudo parted -s /dev/vdX mklabel gpt
    sudo parted -s /dev/vdX mkpart primary xfs 1MiB 2049MiB
    sudo parted -s /dev/vdX set 3 lvm on
    sudo parted /dev/vdX align-check optimal 1

### LVM advanced

    sudo vgcreate -s 32M vg_lab2 /dev/vdb3 /dev/vdd
    sudo lvcreate --type striped -i 2 -L 1G -n lv_stripe vg_lab2
    sudo lvcreate -l 80 -n lv_home2 vg_lab2
    sudo pvmove --alloc anywhere /dev/vdd
    sudo vgreduce vg_lab2 /dev/vdd
    sudo pvremove /dev/vdd && sudo wipefs -a /dev/vdd
    sudo lvextend -l +100%FREE -r /dev/vg_lab2/lv_home2

### Firewalld zones + rich rules

    sudo firewall-cmd --permanent --new-zone=labzone
    sudo firewall-cmd --permanent --zone=labzone --add-rich-rule='rule family="ipv4" source address="10.20.30.100" drop'
    sudo firewall-cmd --set-default-zone=labzone
    sudo nmcli con mod lab-static connection.zone labzone     # preferred over --change-interface
    # --timeout=60s works on runtime rules only; it can't be combined with --permanent

### ACLs

    sudo setfacl -m u:frank:rwx,g:auditors:rx,u:henry:--- /srv/project/phoenix      # access
    sudo setfacl -d -m u:frank:rwx,g:auditors:rx,u:henry:--- /srv/project/phoenix   # default
    getfacl /srv/project/phoenix

### SSH Match block

    Match User emma
        PasswordAuthentication no
        AuthenticationMethods publickey

### Text tools & archives

    grep -E '^[^:]+:[^:]*:210[0-3]:' /etc/passwd
    grep -Ev '^[[:space:]]*(#|$)' FILE        # active config lines only
    CMD > out 2> err  /  CMD >> out  /  CMD &> both
    CMD | sudo tee /root/out > /dev/null      # write a root-owned file (tee -a = append)
    su - USER                                 # login shell
    sudo tar -cJf A.tar.xz DIR ; sudo tar -xJf A.tar.xz -C DEST path/in/archive

---

## 📚 Delta from Exam #1 — What This Exam Emphasizes

| Area            | Exam#1 approach           | Exam#2 approach                                                                                |
| --------------- | ------------------------- | ---------------------------------------------------------------------------------------------- |
| Boot target     | graphical → multi-user   | rescue → graphical                                                                            |
| Partitions      | `fdisk` interactive     | `parted -s` scripted                                                                         |
| Filesystems     | XFS + ext4                | XFS +**VFAT** + noexec/nodev/nosuid                                                      |
| Swap            | Partition                 | **Swap file**                                                                            |
| LVM             | Linear LVs                | **Striped LV**, `pvmove`, `vgreduce`                                                 |
| Firewall        | Services in`public`     | **Custom zone** + rich rule + default zone                                               |
| Sudo            | Group NOPASSWD            | **User_Alias + Cmnd_Alias** + PAM pwquality                                              |
| Permissions     | ugo/rwx + setgid          | **ACLs** (default + access)                                                              |
| SSH             | Simple key auth           | **`Match User`** + no-pw for specific user                                             |
| Repos           | One file, gpgcheck=0      | **Two files**, GPG import, priorities                                                    |
| Flatpak         | DVD sideload, system-wide | **Flathub remote + install**                                                             |
| RPM             | Install/verify            | **`rpm -V` after tampering + reinstall**                                               |
| NFS             | v3/v4                     | **v4 only** + disable v3                                                                 |
| AutoFS          | Direct + indirect         | **Wildcard indirect** + timeout + ghost                                                  |
| Tuned           | Custom merged             | **Custom profile inheriting**                                                            |
| Cron/Timer      | Hourly timer              | **3-hour timer + Persistent=true**                                                       |
| Scripting       | `if/elif`               | **`case` + `while read` CSV parsing + `trap`**                                     |
| SELinux         | httpd default root        | httpd**custom root** + **port 2222**                                               |
| Essential tools | Links + find + tar.bz2    | **`grep -E` regex** + stdout/stderr split + `su -` + **tar.xz member extract** |

---

*Practice exam #2 created 2026-07-08 based on RHEL 10 EX200 objectives.*
*Companion to Exam #1 (2026-05-12); designed to cover the same objectives with fresh scenarios and value swaps.*
*Restructured 2026-09-09: inline solutions, the command quick-reference, and the Delta table moved below the answer key divider so the exam can be re-run cold.*
*Answer key expanded 2026-10-19: full solutions + verify steps for all 35 tasks; corrected T15 (reinstall doesn't restore a modified `%config(noreplace)` file), T20 (segment type stays `striped`), T27 (chronyd exits on SIGHUP, so the step now uses sshd), T34 (plain `cp` already gets the right label); added gotchas for RHEL 10 BLS kernel args, `/net -hosts` in auto.master, `root_squash` vs. T22's root write, and `showmount` on a v4-only server.*
