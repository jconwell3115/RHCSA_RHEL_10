---
title: RHCSA Practice Exam 2 - RHEL 10
tags: [certifications, rhcsa, rhel10, practice, linux]
created: 2026-07-08
restructured: 2026-09-09 - answer key moved to bottom for cold re-runs
note: Answer key is at the BOTTOM of this file. Do not scroll past the Grading Checklist during a timed run.
---

# 🧪 RHCSA Practice Exam #2 — RHEL 10 (EX200)

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

### VM Configuration Notes

- Install **RHEL 10** minimal install on both VMs
- Suggested IPs (different subnet than Exam #1 to avoid stale ARP/host key issues):
  - `rhel10-charlie`: `10.20.30.11/24`
  - `rhel10-delta`: `10.20.30.12/24`
- **Break-in target is `charlie` this time** — forget the root password on `charlie` before starting
- Boot `delta` into `rescue.target` initially so Task 2 forces you to change it
- Do **not** pre-configure repos, SSH keys, or firewall rules — those are exam tasks
- Add the extra disks **after** the OS install, unpartitioned

### Repo Setup (Pre-Task — Simulates Exam Environment)

- Register with `subscription-manager` **or** mount the RHEL 10 ISO
- Do not create the repo files yet — that's Task 13
- If offline, keep the ISO attached at `/dev/sr0`

---

## 📋 Exam Instructions

1. All tasks must be completed on the correct host (`charlie` or `delta`)
2. All configurations must survive a `reboot` — test this for critical tasks
3. Work methodically; a wrong `fstab` entry can break boot
4. Do NOT delete pre-existing users, groups, files, or services unless explicitly told to
5. If a task depends on a previous one and you cannot complete the previous, **still attempt the current one** on a plausible substitute
6. **Do not scroll to the answer key.** If you're stuck, use `man` — that's the skill being tested

---

## 🚀 PRACTICE EXAM #2 — 35 TASKS

---

### SECTION 1: System Recovery & Boot Management

---

**Task 1 — Emergency Recovery via GRUB Kernel Argument** *(charlie)*

> Objective: Interrupt the boot process in order to gain access to a system

The root password on `rhel10-charlie` is unknown. This time, use the **`init=/bin/bash`** method (not `rd.break`) to recover:

1. Interrupt GRUB, edit the kernel line, replace `ro` with `rw` and append `init=/bin/bash`
2. Boot to a raw bash shell
3. Reset the root password to `Ex200Pass!`
4. Ensure SELinux will relabel on next boot
5. Reboot cleanly

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
      auditors   GID: 6002  (system group)

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
- Test the policy by trying to set a bad password for `gina`

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
2. Create a **new** profile `lab-highio` in `/etc/tuned/lab-highio/tuned.conf`:
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
7. Send `SIGHUP` to `chronyd` and confirm via journal that it re-read its config

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
6. Set the boolean `container_manage_cgroup` on persistently
7. Copy `/etc/motd` to `/var/www/html/motd.txt`; observe its context is `admin_home_t` or `etc_t`; fix it so it becomes `httpd_sys_content_t`

---

### SECTION 11: Containers with Podman

---

**Task 35 — Rootless Container with Persistent Volume + Quadlet Timer** *(charlie, as user `emma`)*

> Objective: Find/retrieve/inspect images; run containers; configure as systemd service; attach persistent storage

As user `emma` (rootless):

1. Enable **linger** for `emma`
2. Log in as `emma`, ensure `XDG_RUNTIME_DIR` is set
3. Search and pull `registry.access.redhat.com/ubi10/nginx-124` (**nginx**, not httpd this time)
4. Inspect the image; note the exposed port and the user it runs as
5. Create a named **podman volume** `emma-nginx-data` and place an `index.html` in it containing `Emma Nginx OK`
6. Create Quadlet **volume** and **container** files under `~/.config/containers/systemd/`:
   - A `.volume` unit declaring the named volume
   - A `.container` unit running the nginx image as `emma_nginx`, publishing host port `9090` to container port `8080`, mounting the volume at the nginx web root with the correct SELinux relabel flag, restarting always, and allowing a generous start timeout
7. Reload the user daemon and start the service
8. Test: `curl http://localhost:9090/` from `emma`
9. **Bonus** — create a **Quadlet timer** that restarts the container every night at 03:00
10. Reboot; verify container starts automatically without emma logging in

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
| 35 | Rootless nginx Quadlet + timer + linger           |     ✓     | [ ] |

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
    chk "T28 ForwardToSyslog"           "grep -qE '^ForwardToSyslog=yes' /etc/systemd/journald.conf"
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
    chk "T34 container_manage_cgroup"   "getsebool container_manage_cgroup | grep -q ' on$'"
    ;;
  *delta*)
    chk "T2  default graphical"         "systemctl get-default | grep -qx graphical.target"
    chk "T4  hostname delta"            "hostnamectl --static | grep -qx delta.ex200.lab"
    chk "T4  IPv4 10.20.30.12"          "ip -4 addr show | grep -q '10.20.30.12'"
    chk "T4  IPv6 fd42::12"             "ip -6 addr show | grep -q 'fd42::12'"
    chk "T10 hard link demo"            "test -f /root/link_notes.txt"
    chk "T11 PermitRootLogin prohibit"  "sshd -T 2>/dev/null | grep -qi 'permitrootlogin prohibit-password'"
    chk "T11 AllowUsers set"            "grep -qE '^AllowUsers' /etc/ssh/sshd_config"
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

---

### Section 1 — Boot & Recovery

**T1 — Break-in via init=/bin/bash**

```bash
# At GRUB: 'e', on the linux line change ro -> rw, append init=/bin/bash, Ctrl-X
mount -o remount,rw /       # if needed
passwd root                 # Ex200Pass!
touch /.autorelabel
exec /sbin/init             # or: sync; reboot -f
```

Different from `rd.break` — you skip systemd entirely, so the root filesystem is already mounted by the kernel.

**T2 — Rescue → graphical**

```bash
systemctl set-default graphical.target
dnf group install "Server with GUI"
systemctl get-default
runlevel        # shows 5
```

**T3 — Bootloader**

```bash
vim /etc/default/grub    # remove rhgb quiet; add audit=1 net.ifnames=0; GRUB_TIMEOUT=5
grub2-mkconfig -o /boot/grub2/grub.cfg
dracut -f
reboot
cat /proc/cmdline
```

> `net.ifnames=0` reverts to legacy `ethX` naming — do this **before** Task 4/5, since the interface name changes.

---

### Section 5 — Software Management

**T13 — Two repo files + GPG**

```bash
dnf --disablerepo="*" --enablerepo="lab-baseos" list available | head
```

**T14 — Flatpak remote**

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

**T15 — RPM verify / reinstall**

```bash
rpm -V nano                 # clean = no output
# after editing /etc/nanorc:
rpm -V nano                 # S.5....T.  c /etc/nanorc
dnf reinstall nano
rpm -qf /etc/hosts
rpm -ql chrony
rpm -qa --last | head
```

---

### Section 6 — Storage

**T16 — parted scripted**

```bash
parted -s /dev/vdb mklabel gpt
parted -s /dev/vdb mkpart primary xfs 1MiB 2049MiB
parted -s /dev/vdb mkpart primary linux-swap 2049MiB 3073MiB
parted -s /dev/vdb mkpart primary 3073MiB 100%
parted -s /dev/vdb set 3 lvm on
```

**T20 — pvmove, vgreduce, extend**

`lv_stripe` is striped 2-way across `vdb3` and `vdd`, so a plain `pvmove` has nowhere to put its extents once `vdd` is gone — LVM needs as many target PVs as stripes unless you force it. `--alloc anywhere` collapses it onto the single remaining PV, and `lv_stripe`'s segment type becomes linear.

```bash
pvmove --alloc anywhere /dev/vdd
vgreduce vg_lab2 /dev/vdd
pvremove /dev/vdd
lvextend -l +100%FREE -r /dev/vg_lab2/lv_home2
```

---

### Section 7 — NFS & AutoFS

**T21 — NFSv4-only exports**

`/etc/nfs.conf`: under `[nfsd]` set `vers3=n`, `vers4=y`, `vers4.2=y`.

```text
/srv/nfs/projects  10.20.30.0/24(rw,sync,sec=sys,no_subtree_check)
/srv/nfs/archive   charlie.ex200.lab(ro,sync,sec=sys,root_squash)
```

**T22 — NFS client fstab**

```text
delta:/srv/nfs/projects  /mnt/projects  nfs4  _netdev,nofail,rw  0 0
delta:/srv/nfs/archive   /mnt/archive   nfs4  _netdev,nofail,ro  0 0
```

**T23 — AutoFS wildcard indirect map**

`/etc/auto.master.d/labhome.autofs`:

```text
/net/homes  /etc/auto.labhome  --timeout=60 --ghost
```

`/etc/auto.labhome`:

```text
*  -fstype=nfs4,rw,soft  delta.ex200.lab:/srv/nfs/homes/&
```

**T24 — SUID inventory**

```bash
find /usr/bin -perm -4000 -type f > /root/suid_list.txt
```

> Heads up: the Linux kernel ignores the setuid bit on shebang scripts, so step 3's `4754` on `run_report.sh` sets the bit correctly but will not actually elevate privilege at exec time.

---

### Section 8 — Services, Logging & Time

**T25 — Chrony server**

On delta, add `allow 10.20.30.0/24` to `/etc/chrony.conf`. On charlie, comment out the pool/server defaults and add `server delta.ex200.lab iburst`.

**T27 — Process management**

```bash
openssl speed -multi 2 &
dd if=/dev/zero of=/dev/shm/memtest bs=1M count=800 &
# or: stress-ng --vm 1 --vm-bytes 800M --timeout 60s &
free -h
rm -f /dev/shm/memtest      # tmpfs file stays resident after dd exits

ps -eo pid,pri,ni,pcpu,comm --sort=-pcpu | head
renice -n 19 -p <pid>
systemd-run --scope -p CPUQuota=20% stress-ng --cpu 1 --timeout 30s
pkill -f stress-ng
pkill -f openssl
sudo kill -HUP $(pgrep chronyd)
journalctl -u chronyd -n 20
```

**T28 — Journal forwarding + logrotate**

`/etc/systemd/journald.conf`: `Storage=persistent`, `SystemMaxUse=500M`, `ForwardToSyslog=yes`.

rsyslog rule: `authpriv.*    /var/log/secure.lab`

`/etc/logrotate.d/secure.lab`:

```text
/var/log/secure.lab {
    weekly
    rotate 8
    missingok
    notifempty
    compress
    delaycompress
}
```

```bash
journalctl _COMM=sudo
journalctl --vacuum-time=7d
```

**T29 — Timer every 3 hours**

`OnCalendar=*-*-* 00/3:00:00` with `Persistent=true`. Weekday cron for emma: `15 7 * * 1-5 df -h > ~/disk_report.log`.

---

### Section 9 — Scripting

**T31 — Random password**

`openssl rand -base64 12` yields a 16-character base64 string.

**T32 — Cron "every day except the 1st"**

Cron has no "except" operator — use a day-of-month range: `0 6 2-31 * * /root/health_report.sh`

---

### Section 10 — SELinux

**T33 — Custom web root**

```bash
journalctl -u httpd
ausearch -m avc -ts recent
semanage fcontext -a -t httpd_sys_content_t '/srv/websites(/.*)?'
restorecon -Rv /srv/websites
curl http://localhost/
ps -eZ | grep httpd
```

**T34 — Non-standard SSH port**

```bash
semanage port -a -t ssh_port_t -p tcp 2222
firewall-cmd --permanent --zone=labzone --add-port=2222/tcp
firewall-cmd --reload
ss -tlnp | grep -E ':22|:2222'
getsebool ssh_sysadm_login
setsebool -P container_manage_cgroup on
restorecon -v /var/www/html/motd.txt
```

---

### Section 11 — Containers

**T35 — Quadlet volume + container**

`~/.config/containers/systemd/emma-nginx.volume`:

```ini
[Volume]
VolumeName=emma-nginx-data
```

`~/.config/containers/systemd/emma-nginx.container`:

```ini
[Unit]
Description=Emma Nginx Web
Wants=network-online.target
After=network-online.target

[Container]
Image=registry.access.redhat.com/ubi10/nginx-124
ContainerName=emma_nginx
PublishPort=9090:8080
Volume=emma-nginx-data:/opt/app-root/src:Z

[Service]
Restart=always
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

```bash
loginctl enable-linger emma
podman run --rm -v emma-nginx-data:/data ubi10/nginx-124 \
  sh -c 'echo "Emma Nginx OK" > /data/index.html'
systemctl --user daemon-reload
systemctl --user start emma-nginx.service
curl http://localhost:9090/
```

---

## 🔑 Key Commands Quick Reference (Exam #2 focus)

### Boot / Recovery

    # init=/bin/bash method
    # Boot GRUB -> 'e' -> replace ro with rw -> append init=/bin/bash -> Ctrl-x
    mount -o remount,rw /
    passwd
    touch /.autorelabel
    exec /sbin/init          # graceful, or sync; reboot -f

### Parted (scripted)

    parted -s /dev/vdX mklabel gpt
    parted -s /dev/vdX mkpart primary xfs 1MiB 2049MiB
    parted -s /dev/vdX set 3 lvm on
    parted /dev/vdX align-check optimal 1

### LVM advanced

    lvcreate --type striped -i 2 -L 1G -n lv_stripe vg_lab2
    pvmove --alloc anywhere /dev/vdd
    vgreduce vg_lab2 /dev/vdd
    lvextend -l +100%FREE -r /dev/vg_lab2/lv_home2

### Firewalld zones + rich rules

    firewall-cmd --permanent --new-zone=labzone
    firewall-cmd --permanent --zone=labzone --add-rich-rule='rule family=ipv4 source address=10.20.30.100 drop'
    firewall-cmd --set-default-zone=labzone
    firewall-cmd --permanent --zone=labzone --change-interface=eth0

### ACLs

    setfacl -m u:frank:rwx /srv/project/phoenix
    setfacl -d -m g:auditors:rx /srv/project/phoenix
    getfacl /srv/project/phoenix

### SSH Match block

    Match User emma
        PasswordAuthentication no
        AuthenticationMethods publickey

### Podman Quadlet

    loginctl enable-linger USER
    systemctl --user daemon-reload
    systemctl --user start service-name.service
    journalctl --user -u service-name.service

---

## 📚 Delta from Exam #1 — What This Exam Emphasizes

| Area          | Exam#1 approach         | Exam#2 approach                                             |
| ------------- | ----------------------- | ----------------------------------------------------------- |
| Root recovery | `rd.break`            | `init=/bin/bash`                                          |
| Boot target   | graphical → multi-user | rescue → graphical                                         |
| Partitions    | `fdisk` interactive   | `parted -s` scripted                                      |
| Filesystems   | XFS + ext4              | XFS +**VFAT** + noexec/nodev/nosuid                   |
| Swap          | Partition               | **Swap file**                                         |
| LVM           | Linear LVs              | **Striped LV**, `pvmove`, `vgreduce`              |
| Firewall      | Services in`public`   | **Custom zone** + rich rule + default zone            |
| Sudo          | Group NOPASSWD          | **User_Alias + Cmnd_Alias** + PAM pwquality           |
| Permissions   | ugo/rwx + setgid        | **ACLs** (default + access)                           |
| SSH           | Simple key auth         | **`Match User`** + no-pw for specific user          |
| Repos         | One file, gpgcheck=0    | **Two files**, GPG import, priorities                 |
| Flatpak       | Not covered             | **Flathub remote + install**                          |
| RPM           | Install/verify          | **`rpm -V` after tampering + reinstall**            |
| NFS           | v3/v4                   | **v4 only** + disable v3                              |
| AutoFS        | Direct + indirect       | **Wildcard indirect** + timeout + ghost               |
| Tuned         | Custom merged           | **Custom profile inheriting**                         |
| Cron/Timer    | Hourly timer            | **3-hour timer + Persistent=true**                    |
| Scripting     | `if/elif`             | **`case` + `while read` CSV parsing + `trap`**  |
| SELinux       | httpd default root      | httpd**custom root** + **port 2222**            |
| Containers    | httpd Quadlet           | **nginx** rootless + **volume Quadlet** + timer |

---

*Practice exam #2 created 2026-07-08 based on RHEL 10 EX200 objectives.*
*Companion to Exam #1 (2026-05-12); designed to cover the same objectives with fresh scenarios and value swaps.*
*Restructured 2026-09-09: inline solutions, the command quick-reference, and the Delta table moved below the answer key divider so the exam can be re-run cold.*
