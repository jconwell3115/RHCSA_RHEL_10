---
title: RHCSA Practice Exam - RHEL 10
tags: [certifications, rhcsa, rhel10, practice, linux]
created: 2026-05-12
restructured: 2026-09-09 - answer key moved to bottom for cold re-runs
note: Answer key is at the BOTTOM of this file. Do not scroll past the Grading Checklist during a timed run.
---
# 🧪 RHCSA Practice Exam — RHEL 10 (EX200)

> **Format:** Performance-based | **Time budget:** 3 hours | **Pass Score:** ~70% (25 / 35)
>
> All configurations **must persist after reboot** without intervention.
>
> You may use `man`, `info`, and `/usr/share/doc` — no internet access on exam day.

> **⏱️ Budget is 3 hours, not 2.5.** 35 tasks at 2.5 hrs works out to ~4.3 min/task, which is not achievable. Don't read a timer overrun as "not ready" — the real EX200 presents far fewer, larger tasks, so per-task pacing here doesn't transfer. Confirm the real exam's current duration on Red Hat's objectives page.

> **📌 Answer key is at the end of this file, not under each task.** This exam originally carried its solutions inline; they were moved on 2026-09-09 so it can be re-run cold. Working it with the answers visible trains recognition — the real exam tests recall.

---

## 🖥️ Lab Environment Setup

### Required Virtual Machines

| VM               | vCPU | RAM  | Primary Disk      | Extra Disks                              |
| ---------------- | ---- | ---- | ----------------- | ---------------------------------------- |
| `rhel10-alpha` | 2    | 2 GB | 20 GB`/dev/vda` | none (add 10 GB`/dev/vdb` after setup) |
| `rhel10-bravo` | 2    | 2 GB | 20 GB`/dev/vda` | 10 GB`/dev/vdb`, 5 GB `/dev/vdc`     |

### VM Configuration Notes

- Install **RHEL 10** minimal install on both VMs
- Set up a **NAT/Host-Only network** so both VMs can communicate
- Suggested IPs:
  - `rhel10-alpha`: `192.168.100.10/24`
  - `rhel10-bravo`: `192.168.100.20/24`
- **Do NOT** configure SSH root login or repo access — those are exam tasks
- Set root password on alpha to something you remember; **forget it on bravo** (Task 1 requires breaking in)
- Add the 10 GB disk to `rhel10-alpha` **unpartitioned** after OS install for storage tasks

### Repo Setup (Pre-Task — Simulates Exam Environment)

The real exam has repos pre-configured or gives you a URL. For lab purposes, either:

- Subscribe with a Red Hat Developer account: `subscription-manager register`
- Or mount the RHEL 10 ISO and configure a local repo (covered in Task 13)

---

## 📋 Exam Instructions

Read carefully before beginning:

1. All tasks must be completed on the correct host (alpha or bravo)
2. All configurations must survive a `reboot` — test this for critical tasks
3. Partial credit is not given on the real exam — complete each task fully
4. Work methodically; a wrong fstab entry can break boot
5. **Do not scroll to the answer key.** If you're stuck, use `man` — that's the skill being tested

---

## 🚀 PRACTICE EXAM — 35 TASKS

---

### SECTION 1: System Recovery & Boot Management

---

**Task 1 — Break Into bravo and Reset Root Password** *(bravo)*

> Objective: Interrupt the boot process in order to gain access to a system

The root password on `rhel10-bravo` is unknown. Break into the system using the `init=/bin/bash` method, reset the root password to `RedHat10!`, and ensure SELinux labels are updated before the next boot. Reboot and confirm login.

---

**Task 2 — Configure Boot Target** *(bravo)*

> Objective: Boot systems into different targets manually

After breaking into bravo, confirm it is currently booting to `graphical.target`. Change the default boot target to `multi-user.target`. Reboot and verify the system boots without a GUI.

---

**Task 3 — Modify the Bootloader** *(alpha)*

> Objective: Modify the system bootloader

Edit the GRUB configuration on `rhel10-alpha` with the following changes:

- Set `GRUB_TIMEOUT=10`
- Add the line: `GRUB_TIMEOUT_STYLE=countdown`
- Append `quiet` to the end of `GRUB_CMDLINE_LINUX`

Regenerate the GRUB config and reboot to verify.

---

### SECTION 2: Networking & Hostname

---

**Task 4 — Configure Static IP and Hostname** *(both nodes)*

> Objective: Configure IPv4 and IPv6 addresses, Configure hostname resolution

Configure the following on each server using `nmcli`. Configurations must survive reboot.

| Host  | Hostname            | IPv4                  | IPv6            | Gateway           |
| ----- | ------------------- | --------------------- | --------------- | ----------------- |
| alpha | `alpha.lab.local` | `192.168.100.10/24` | `fd00::10/64` | `192.168.100.1` |
| bravo | `bravo.lab.local` | `192.168.100.20/24` | `fd00::20/64` | `192.168.100.1` |

Also set DNS to `8.8.8.8` and `1.1.1.1`. Add entries for both hosts to `/etc/hosts` on both systems. Confirm connectivity between nodes by hostname.

---

**Task 5 — Configure Firewall for SSH and HTTP** *(alpha)*

> Objective: Restrict network access using firewall-cmd/firewalld

On `alpha`:

- Ensure `sshd` is permanently allowed in the `public` zone
- Permanently allow HTTP traffic (port 80/tcp) in the `public` zone
- Add a runtime-only rule allowing port `8080/tcp`
- Permanently allow TCP ports `5900-5910` in the `internal` zone
- Reload the firewall and confirm rules persist

---

### SECTION 3: Users, Groups & Permissions

---

**Task 6 — Create Users and Groups** *(alpha)*

> Objective: Create, delete, and modify local user accounts and groups

Create the following users and groups. All UIDs and GIDs must be set as specified.

```
Groups:
  sysadmins  GID: 5000
  developers GID: 5001
  contractors GID: 5002

Users:
  alice   UID: 1050  primary: developers   supplementary: sysadmins
  bob     UID: 1051  primary: developers   supplementary: contractors  shell: /bin/bash
  carol   UID: 1052  primary: contractors  no login shell
  dave    UID: 1053  primary: sysadmins    account expires: 90 days from today
```

Verify each user's entry in `/etc/passwd` and group memberships with `id`.

---

**Task 7 — Password Aging Policy** *(alpha)*

> Objective: Change passwords and adjust password aging for local user accounts

- Set the password for all users created in Task 6 to `Lab@12345` — do it non-interactively, in one command
- Using `chage`, configure `alice` with: minimum 7 days, maximum 60 days, warn 10 days
- Using `passwd`, configure `bob` with: minimum 5 days, maximum 90 days, warn 14 days, inactive 10 days
- Force `carol` to change her password on next login
- Set system-wide minimum password length to 8 characters in `/etc/login.defs`

---

**Task 8 — Configure sudo Access** *(alpha)*

> Objective: Configure privileged access

Create a sudoers drop-in file in `/etc/sudoers.d/`. Configure:

- `sysadmins` group: full sudo access with no password
- `developers` group: can run `dnf` and `systemctl` with sudo
- `alice`: can run `/usr/sbin/useradd` and `/usr/sbin/userdel` only
- Create a command alias `PKGMGMT` for `/usr/bin/dnf`

Validate using `sudo -l -U alice`.

---

**Task 9 — Set-GID Collaborative Directory** *(alpha)*

> Objective: Create and configure set-GID directories for collaboration

Create a shared directory `/data/devshare`:

- Owned by `alice:developers`
- Permissions: owner=rwx, group=rwx, other=no access
- Set the **set-GID** bit so new files inherit the `developers` group
- Set the **sticky bit** so users can only delete their own files
- Create a test file as `bob` and verify group ownership is `developers`

---

**Task 10 — Standard File Permissions & Umask** *(both nodes)*

> Objective: Manage default file permissions, List/set/change standard ugo/rwx permissions

- On `alpha`, configure the system-wide umask so all newly created files default to `660` and directories default to `770`. Make this persistent for all users.
- On `bravo`, apply the same setting.
- Verify by creating a test file and directory as a regular user.

---

### SECTION 4: SSH & Remote Access

---

**Task 11 — Configure Key-Based SSH Authentication** *(alpha → bravo)*

> Objective: Configure key-based authentication for SSH, Access remote systems using SSH

On `alpha` as `root`:

1. Generate an RSA key pair (4096-bit, no passphrase)
2. Copy the public key to `root@bravo`
3. Confirm passwordless SSH from alpha to bravo

On `alpha` as `alice`:

1. Generate an ed25519 key pair
2. Copy the public key to `alice@bravo` (create alice on bravo if needed)
3. Confirm passwordless SSH from alice@alpha to alice@bravo

Ensure `PermitRootLogin yes` & `PasswordAuthentication yes` is set in `/etc/ssh/sshd_config` on bravo.

---

**Task 12 — Secure File Transfer** *(alpha → bravo)*

> Objective: Securely transfer files between systems

- Use `scp` to copy `/etc/hosts` from alpha to `/tmp/hosts_from_alpha` on bravo
- Use `rsync` to synchronize the `/etc/sysconfig/` directory from alpha to `/tmp/sysconfig_backup/` on bravo
- Use `sftp` interactively to upload `/etc/motd` from alpha to bravo's `/tmp/`

---

### SECTION 5: Software Management

---

> **Environment prep (not a graded task):** If the VM was registered with Red Hat, disable the builtin repos before continuing.

```bash
sudo subscription-manager repos --disable=rhel-10-for-x86_64-baseos-rpms
sudo subscription-manager repos --disable=rhel-10-for-x86_64-appstream-rpms

# Clean and Verify
sudo dnf clean all
dnf repolist
```

**Task 13 — Configure Repositories** *(alpha)*

> Objective: Install and update software packages from Red Hat CDN, remote repo, or local file system.  Ensure it persists after reboot.

Configure a local YUM/DNF repository from the RHEL 10 installation ISO:

1. Mount the RHEL 10 ISO at `/mnt/rhel10iso`
2. Create a repo file `/etc/yum.repos.d/rhel10-local.repo` with:
   - `[BaseOS]` section pointing to `file:///mnt/rhel10iso/BaseOS`
   - `[AppStream]` section pointing to `file:///mnt/rhel10iso/AppStream`
   - Both enabled, `gpgcheck=0`
3. Verify with `dnf repolist`
4. Make the mount persist across reboot — and test that persistence **without** rebooting

---

**Task 14 — Package Management Operations** *(alpha)*

> Objective: Install and remove RPM software packages

- Install the `vim-enhanced`, `tmux`, and `wget` packages
- Verify `httpd` package is not installed; install it
- Query the installed `httpd` package and list all its configuration files
- Download (but don't install) the `nmap` package RPM to `/root/downloads/`
- Use `rpm` to verify the integrity of a package file
- Install `nmap` from the downloaded RPM
- Remove `nmap` with `rpm`

---

**Task 15 — Package Groups & Flatpak *(alpha)***

> Objective: Install and update software packages from Red Hat CDN, remote repository, or local file system (RHEL 10 objectives — RPM + Flatpak; modularity is deprecated)

Part A — Package groups:

- List available package groups
- Install the "Development Tools" group
- Remove it

Part B — Flatpak (now a mandatory RHCSA objective):

- Add the Flathub remote
- Search for, install, run, update, and remove an application
- Clean up unused runtimes

Part C — Installing an alternate app-stream version (the modern replacement for module streams):

- Discover what versioned `postgresql` packages are available, install `postgresql-server`, and confirm the installed version
- Determine whether `postgresql` is delivered as a module on RHEL 10, and record what you find

---

### SECTION 6: Storage — Partitions, LVM & Swap

> **Note:** These tasks use the extra disk `/dev/vdb` on bravo (or alpha if you added one)

---

**Task 16 — Create GPT Partitions** *(bravo, /dev/vdb)*

> Objective: List, create, delete partitions on GPT disks

Using `/dev/vdb` on bravo:

1. Create a GPT partition table
2. Create a 1 GiB partition (`vdb1`) — type: Linux filesystem
3. Create a 500 MiB partition (`vdb2`) — type: Linux swap
4. Create a 2 GiB partition (`vdb3`) — type: Linux filesystem
5. Run `partprobe` to inform the kernel
6. Verify with `lsblk` and `fdisk -l /dev/vdb`

---

**Task 17 — Create and Mount File Systems by UUID** *(bravo)*

> Objective: Configure systems to mount file systems at boot by UUID or label, Create/mount/unmount VFAT, ext4, XFS

1. Format `vdb1` as **XFS**
2. Format `vdb3` as **ext4** with label `DATASTORE`
3. Create mount points `/mnt/xfs_data` and `/mnt/ext4_data`
4. Add persistent entries to `/etc/fstab` using **UUID** for xfs_data and **LABEL** for ext4_data
5. Run `mount -a` and verify with `df -hT`
6. Create a test file in each mount point and reboot to confirm persistence

---

**Task 18 — Configure Swap Space** *(bravo)*

> Objective: Add new partitions, logical volumes, and swap to a system non-destructively

1. Format `vdb2` as swap with label `EXTRASWAP`
2. Add a persistent swap entry to `/etc/fstab` with priority `10`
3. Activate the swap and verify with `swapon -s` and `free -h`
4. Reboot and confirm the swap and its priority survived

---

**Task 19 — Create and Manage LVM** *(bravo, /dev/vdc)*

> Objective: Create/remove physical volumes, assign to VGs, create/delete LVs

Using `/dev/vdc` (full disk, unpartitioned):

1. Initialize `/dev/vdc` as a physical volume
2. Create a volume group `vg_lab` with PE size 16 MiB
3. Create logical volume `lv_data` with size **500 MiB**
4. Create logical volume `lv_logs` using **25 extents**
5. Format `lv_data` as XFS and `lv_logs` as ext4
6. Mount both persistently under `/mnt/lv_data` and `/mnt/lv_logs`
7. Verify with `pvs`, `vgs`, `lvs`

---

**Task 20 — Extend a Logical Volume** *(bravo)*

> Objective: Extend existing logical volumes, Add new partitions and LVs non-destructively

Extend the `lv_data` logical volume (from Task 19) to **1 GiB** total size:

1. Verify there is enough free space in `vg_lab`
2. Extend the LV and grow the filesystem in one command
3. Confirm the new size with `df -h /mnt/lv_data`

---

### SECTION 7: File Systems & NFS

---

**Task 21 — Configure NFS Server** *(bravo)*

> Objective: Mount and unmount network file systems using NFS

On `bravo` (NFS server):

1. Install `nfs-utils`
2. Create directories `/export/shared` and `/export/readonly`
3. Make `/export/shared` genuinely writable by clients — you should be able to name more than one approach and justify the one you pick
4. Add entries to `/etc/exports`:
   - `/export/shared` — read/write for `192.168.100.0/24`
   - `/export/readonly` — read-only for `192.168.100.10`
5. Start and enable `nfs-server.service`
6. Add permanent firewall rules for `nfs`, `mountd`, `rpc-bind`
7. Confirm exports with `exportfs -v`

---

**Task 22 — Mount NFS on Client** *(alpha)*

> Objective: Mount and unmount network file systems using NFS

On `alpha` (NFS client):

1. Create mount points `/mnt/nfs_shared` and `/mnt/nfs_ro`
2. Mount them using NFS entries in `/etc/fstab` with the `_netdev` option
3. Verify with `mount -a` and `df -hT`
4. Create a test file in `/mnt/nfs_shared` and verify it appears on bravo

---

**Task 23 — Configure AutoFS** *(alpha)*

> Objective: Configure autofs

On `alpha`, configure `autofs` to automatically mount user home directories from bravo:

1. Install `autofs`
2. Configure a direct map for `/export/shared` from bravo at the local path `/autodir`
3. Configure an indirect map so user home directories from `bravo:/export/home` auto-mount under `/mnt/autohome/<username>` on access
4. Start and enable `autofs`
5. Test by switching to a user whose home directory should be mounted

> You will need to create and export `/export/home` on bravo first, with a test user whose home lives there.

---

**Task 24 — File Permission Diagnostics** *(alpha)*

> Objective: Diagnose and correct file permission problems

The following files and directories have incorrect permissions. Fix them:

1. `/var/www/html/` — should be owned by `root:root`, world-readable, but not world-writable
2. Create `/secure/app/` — owned by `alice:developers`, no access for others, SGID set
3. A file `/tmp/badperms` exists with permissions `777` — change to `640`, owner `bob`, group `developers`
4. Find all world-writable files under `/etc` and report them (save list to `/root/world_writable.txt`)

---

### SECTION 8: System Services, Logging & Time

---

**Task 25 — Configure Time Synchronization** *(both nodes)*

> Objective: Configure time service clients

1. Install `chrony` if not present
2. Configure `/etc/chrony.conf` to use `pool 2.rhel.pool.ntp.org iburst` as the primary source
3. Start and enable `chronyd`
4. Verify sync with `chronyc tracking` and `timedatectl`
5. Set the timezone to `America/Chicago` on alpha and `UTC` on bravo

---

**Task 26 — Manage Tuning Profiles** *(alpha)*

> Objective: Manage tuning profiles

1. Install and start the `tuned` service
2. List all available profiles
3. Display the currently active profile
4. Change the active profile to `throughput-performance`
5. Verify the active profile
6. Set up a **merged profile** combining `virtual-guest` and `powersave` — create a custom profile called `lab-custom` in `/etc/tuned/lab-custom/`
7. Apply `lab-custom` as the active profile
8. Make sure it survives a reboot — verify every file that controls profile persistence on RHEL 10

---

**Task 27 — Process Management** *(alpha)*

> Objective: Identify CPU/memory intensive processes and kill processes, Adjust process scheduling

1. Launch three background `dd if=/dev/zero of=/dev/null` processes
2. Use `ps`, `top`, or `pidstat` to identify them
3. Use `renice` to change the niceness of one process to `10`
4. Use `renice` to change the same process niceness to `-5` (requires root)
5. Kill all `dd` processes using `killall`
6. Start a `sleep 3600` process, then send it `SIGSTOP`, then `SIGCONT`, then `SIGTERM`
7. Use `nice` to launch a new process `sleep 1000` with niceness `15`

---

**Task 28 — Persistent Journal and Log Management** *(both nodes)*

> Objective: Locate and interpret system log files and journals, Preserve system journals

1. Configure `systemd-journald` to store logs persistently by editing `/etc/systemd/journald.conf`
2. Verify the journal directory is created at `/var/log/journal/`
3. Use `journalctl` to:
   - Show logs since last boot
   - Filter logs for the `sshd` service
   - Show only error-level and above messages
   - Show the last 50 lines
4. Configure `rsyslog` to write all `*.info` messages to `/var/log/messages.info`
5. Use `logger` to send a test message and verify it appears in the correct log file

---

**Task 29 — Schedule Tasks** *(alpha)*

> Objective: Schedule tasks using at, cron, and systemd timer units

1. Using `at`, schedule a job to run in 5 minutes that appends `"Scheduled at task ran"` to `/var/log/at_test.log`
2. Using `crontab -e` for user `alice`, create a cron job that appends the current date to `~/cron_test.log` every day at 8:00 AM
3. Create a **systemd timer** unit that runs a script `/usr/local/bin/hourly_check.sh` every hour. The script should echo the date to `/var/log/hourly.log`
   - Create the service unit: `/etc/systemd/system/hourly-check.service`
   - Create the timer unit: `/etc/systemd/system/hourly-check.timer`
   - Enable and start the timer

---

### SECTION 9: Shell Scripting

---

**Task 30 — Conditional Script** *(alpha)*

> Objective: Conditionally execute code (if, test, [], etc.), Process script inputs ($1, $2, etc.)

Write a script `/usr/local/bin/syscheck.sh` that:

- Accepts one argument: `cpu`, `mem`, `disk`, or `all`
- If `cpu`: display CPU model from `/proc/cpuinfo`
- If `mem`: display total and available memory from `free -h`
- If `disk`: display disk usage summary from `df -hT`
- If `all`: run all three checks
- If no argument or invalid argument: print usage instructions and exit with code `1`
- Make the script executable and test each argument

---

**Task 31 — Looping Script with User Creation** *(alpha)*

> Objective: Use looping constructs (for, etc.), Processing output of shell commands within a script

Write a script `/usr/local/bin/bulk_users.sh` that:

- Reads usernames from `/root/userlist.txt` (create this file with 5 usernames)
- For each username:
  - Create the user if it does not already exist
  - Set the password equal to the username
  - Print a success or "already exists" message
- Use a `for` loop with command substitution

---

**Task 32 — Backup Script with Cron** *(alpha)*

> Objective: Process output of shell commands within a script

Write a script `/root/etcbackup.sh` that:

- Creates a compressed tar archive of `/etc` named with the current date: `etc_backup_YYYY-MM-DD.tar.gz`
- Saves it to `/root/backups/` (create if not exists)
- Removes backups older than 7 days
- Logs the backup filename and timestamp to `/var/log/etcbackup.log`

Schedule this script to run at **11:30 PM every night except Sunday** using cron.

---

### SECTION 10: SELinux

---

**Task 33 — SELinux Modes and Contexts** *(both nodes)*

> Objective: Set enforcing/permissive modes, list/identify SELinux file and process context

1. On `alpha`: Confirm SELinux is in `enforcing` mode — set it persistently if not
2. On `bravo`: Set SELinux to `permissive` mode persistently (edit `/etc/selinux/config`)
3. On `alpha`:
   - Create `/webtest/index.html` with content `"Hello RHCSA"`
   - Check the SELinux context — it will be wrong for serving with httpd
   - Use `semanage fcontext` to add the correct `httpd_sys_content_t` context for `/webtest(/.*)?`
   - Apply the context with `restorecon -Rv /webtest`
   - Start httpd and verify the page is served

---

**Task 34 — SELinux Ports and Booleans** *(alpha)*

> Objective: Manage SELinux port labels, Use boolean settings to modify SELinux settings, Restore default file contexts

1. Configure `httpd` to listen on port `8181`
   - Add the non-standard port to the SELinux policy for `http_port_t`
   - Confirm with `semanage port -l | grep http`
2. Check the current state of the boolean `httpd_can_network_connect`
3. Enable the boolean persistently
4. Check the boolean `httpd_enable_homedirs` and enable it persistently
5. Copy `/etc/hosts` to `/var/www/html/hosts.txt` — check and restore the SELinux context

---

### SECTION 11: Containers with Podman

---

**Task 35 — Deploy a Container as a Systemd Service (Quadlet)** *(alpha, as alice)*

> Objective: Find/retrieve container images, Inspect images, Run containers, Configure container as systemd service, Attach persistent storage

As user `alice` (rootless container):

1. Search for and pull the `ubi10/httpd-24` image from `registry.access.redhat.com`
2. Inspect the image and identify the exposed port
3. Create a directory `~/web_content/` and add a file `index.html` with content: `"Welcome to Alice's Containerized Web Server!"`
4. Run the container named `alice_web` in detached mode:
   - Map local port `8080` to container port `8080`
   - Bind-mount `~/web_content/` to `/var/www/html/` with `:Z` for SELinux
5. Verify the container is running with `podman ps`
6. Test with `curl http://localhost:8080`
7. Create a **Podman Quadlet** at `~/.config/containers/systemd/alice-web.container` that reproduces that container as a user systemd service, starting at login. It must set the image, container name, published port, and the bind-mounted volume with the correct SELinux relabel flag, and restart always.
8. Enable user lingering for `alice`
9. Reload the user daemon and start the service
10. Reboot and confirm the container starts automatically and the webpage is accessible

---

## 📊 Grading Checklist

Mark each task after verifying it survives a reboot where applicable.

| #  | Task                                      | Reboot Test | Done |
| -- | ----------------------------------------- | ----------- | ---- |
| 1  | Break into bravo, reset root password     | ✓          | [ ]  |
| 2  | Set default boot target to multi-user     | ✓          | [ ]  |
| 3  | Modify bootloader (GRUB_TIMEOUT, quiet)   | ✓          | [ ]  |
| 4  | Static IP + IPv6 + hostname + /etc/hosts  | ✓          | [ ]  |
| 5  | Firewall rules (SSH, HTTP, ports)         | ✓          | [ ]  |
| 6  | Create users/groups with UIDs/GIDs        | ✓          | [ ]  |
| 7  | Password aging policies                   | ✓          | [ ]  |
| 8  | sudo access (groups, command alias)       | ✓          | [ ]  |
| 9  | Set-GID collaborative directory           | ✓          | [ ]  |
| 10 | System-wide umask 0007                    | ✓          | [ ]  |
| 11 | Key-based SSH (root + alice)              | ✓          | [ ]  |
| 12 | scp, rsync, sftp transfers                | —          | [ ]  |
| 13 | Configure local DNF repo from ISO         | ✓          | [ ]  |
| 14 | Package install/remove/query with RPM+DNF | —          | [ ]  |
| 15 | Package groups + Flatpak + versioned RPM  | —          | [ ]  |
| 16 | GPT partitions on /dev/vdb                | ✓          | [ ]  |
| 17 | Format + mount by UUID and LABEL          | ✓          | [ ]  |
| 18 | Swap partition with priority              | ✓          | [ ]  |
| 19 | Create LVM (PV, VG, LV) with PE size      | ✓          | [ ]  |
| 20 | Extend LV and grow filesystem live        | ✓          | [ ]  |
| 21 | NFS server with exports + firewall        | ✓          | [ ]  |
| 22 | NFS client persistent mount               | ✓          | [ ]  |
| 23 | AutoFS (direct map + indirect home dirs)  | ✓          | [ ]  |
| 24 | File permission diagnostics + fix         | ✓          | [ ]  |
| 25 | Chrony NTP + timezone                     | ✓          | [ ]  |
| 26 | Tuned profile + custom merged profile     | ✓          | [ ]  |
| 27 | Process management (nice/renice/kill)     | —          | [ ]  |
| 28 | Persistent journal + rsyslog rule         | ✓          | [ ]  |
| 29 | at + cron + systemd timer                 | ✓          | [ ]  |
| 30 | Conditional shell script (syscheck.sh)    | —          | [ ]  |
| 31 | Looping user creation script              | —          | [ ]  |
| 32 | Backup script + cron job                  | ✓          | [ ]  |
| 33 | SELinux modes + fcontext + restorecon     | ✓          | [ ]  |
| 34 | SELinux ports + booleans                  | ✓          | [ ]  |
| 35 | Podman container + Quadlet service        | ✓          | [ ]  |

**Score: ___ / 35**

> Passing threshold (real exam ~70%): **25 / 35**

---

## ✅ Quick Verification Script

Run on the relevant host **after a reboot**. Checks the objectively-verifiable, persistence-sensitive items only — it is a safety net against marking something "done" that didn't actually persist, not a full grader. Tasks needing human judgement (T11 SSH keys, T12 transfers, T30–32 script behaviour) aren't covered.

```bash
#!/usr/bin/env bash
# ex1-verify.sh — spot-check Exam 1 persistence. Run with sudo on each host.
pass=0; fail=0
chk() { # chk "label" "command"
  if eval "$2" &>/dev/null; then printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1))
  else printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); fi
}

echo "== Host: $(hostname -s) =="

case "$(hostname -s)" in
  *alpha*)
    chk "T3  GRUB_TIMEOUT=10"          "grep -q '^GRUB_TIMEOUT=10' /etc/default/grub"
    chk "T3  countdown style"          "grep -q '^GRUB_TIMEOUT_STYLE=countdown' /etc/default/grub"
    chk "T4  hostname alpha.lab.local" "hostnamectl --static | grep -qx alpha.lab.local"
    chk "T4  static IPv4 .10"          "ip -4 addr show | grep -q '192.168.100.10'"
    chk "T4  IPv6 fd00::10"            "ip -6 addr show | grep -q 'fd00::10'"
    chk "T4  bravo in /etc/hosts"      "grep -q 'bravo.lab.local' /etc/hosts"
    chk "T5  http permanent"           "firewall-cmd --list-services | grep -q http"
    chk "T5  internal 5900-5910"       "firewall-cmd --zone=internal --list-ports | grep -q 5900-5910"
    chk "T6  alice uid 1050"           "id -u alice | grep -qx 1050"
    chk "T6  developers gid 5001"      "getent group developers | grep -q ':5001:'"
    chk "T6  carol nologin"            "getent passwd carol | grep -qE '(nologin|false)$'"
    chk "T7  alice max 60 days"        "chage -l alice | grep -qi 'Maximum.*60'"
    chk "T8  sudoers drop-in valid"    "visudo -c &>/dev/null"
    chk "T9  devshare setgid+sticky"   "stat -c '%a' /data/devshare | grep -qx 3770"
    chk "T9  devshare owner"           "stat -c '%U:%G' /data/devshare | grep -qx alice:developers"
    chk "T10 umask drop-in"            "grep -rq 'umask 0*007' /etc/profile.d/"
    chk "T13 iso mounted"              "findmnt /mnt/rhel10iso"
    chk "T13 repo enabled"             "dnf repolist 2>/dev/null | grep -qi appstream"
    chk "T13 fstab has nofail"         "grep -q '/mnt/rhel10iso' /etc/fstab && grep '/mnt/rhel10iso' /etc/fstab | grep -q nofail"
    chk "T24 /var/www/html 755 root"   "stat -c '%a %U' /var/www/html | grep -qx '755 root'"
    chk "T24 /secure/app 2770"         "stat -c '%a' /secure/app | grep -qx 2770"
    chk "T24 badperms 640 bob"         "stat -c '%a %U:%G' /tmp/badperms | grep -qx '640 bob:developers'"
    chk "T25 chronyd enabled"          "systemctl is-enabled --quiet chronyd"
    chk "T25 timezone Chicago"         "timedatectl show -p Timezone --value | grep -qx America/Chicago"
    chk "T26 tuned lab-custom active"  "tuned-adm active | grep -q lab-custom"
    chk "T26 ppd_base_profile set"     "grep -q lab-custom /etc/tuned/ppd_base_profile"
    chk "T28 journal persistent"       "test -d /var/log/journal"
    chk "T28 rsyslog *.info rule"      "grep -qE '^\\*\\.info' /etc/rsyslog.conf"
    chk "T29 hourly timer enabled"     "systemctl is-enabled --quiet hourly-check.timer"
    chk "T29 alice cron 8am"           "crontab -l -u alice 2>/dev/null | grep -q '^0 8'"
    chk "T32 etcbackup cron"           "crontab -l 2>/dev/null | grep -q 'etcbackup.sh'"
    chk "T33 SELinux enforcing"        "getenforce | grep -qx Enforcing"
    chk "T33 webtest labeled"          "ls -Zd /webtest | grep -q httpd_sys_content_t"
    chk "T34 port 8181 labeled"        "semanage port -l | grep http_port_t | grep -q 8181"
    chk "T34 httpd_can_network_connect" "getsebool httpd_can_network_connect | grep -q ' on$'"
    chk "T34 httpd_enable_homedirs"    "getsebool httpd_enable_homedirs | grep -q ' on$'"
    chk "T35 linger enabled for alice" "loginctl show-user alice -p Linger | grep -qi yes"
    chk "T35 container serving 8080"   "curl -sf http://localhost:8080/ | grep -qi alice"
    ;;
  *bravo*)
    chk "T2  default multi-user"       "systemctl get-default | grep -qx multi-user.target"
    chk "T4  hostname bravo.lab.local" "hostnamectl --static | grep -qx bravo.lab.local"
    chk "T4  static IPv4 .20"          "ip -4 addr show | grep -q '192.168.100.20'"
    chk "T10 umask drop-in"            "grep -rq 'umask 0*007' /etc/profile.d/"
    chk "T16 three partitions on vdb"  "test \$(lsblk -no NAME /dev/vdb | tail -n +2 | wc -l) -eq 3"
    chk "T17 xfs_data mounted"         "findmnt /mnt/xfs_data"
    chk "T17 mounted by UUID"          "grep -q '^UUID=' /etc/fstab && grep '/mnt/xfs_data' /etc/fstab | grep -q UUID"
    chk "T17 ext4_data by LABEL"       "grep '/mnt/ext4_data' /etc/fstab | grep -q 'LABEL=DATASTORE'"
    chk "T18 swap active"              "swapon --show | grep -q /dev/vdb2"
    chk "T18 swap priority 10"         "swapon --show=PRIO --noheadings | grep -q 10"
    chk "T19 vg_lab 16M PE"            "vgs --noheadings -o vg_extent_size vg_lab | grep -q '16'"
    chk "T19 lv_data mounted"          "findmnt /mnt/lv_data"
    chk "T19 lv_logs mounted"          "findmnt /mnt/lv_logs"
    chk "T20 lv_data is 1G"            "lvs --noheadings -o lv_size vg_lab/lv_data | grep -q '1\\.00g'"
    chk "T21 nfs-server running"       "systemctl is-active --quiet nfs-server"
    chk "T21 exports present"          "exportfs -v | grep -q /export/shared"
    chk "T21 nfs firewall"             "firewall-cmd --list-services | grep -q nfs"
    chk "T33 SELinux permissive"       "grep -qE '^SELINUX=permissive' /etc/selinux/config"
    ;;
esac

echo "== $pass passed, $fail failed =="
```

---

---

# 🔑 ANSWER KEY

> **Stop.** Do not read this during a timed run. Score yourself from the checklist first, then come back here for the tasks you missed.

---

### Section 1 — System Recovery & Boot Management

**T1 — Break into bravo**

> Note from an earlier run: rd.break drops to an emergency mode, not a shell — `init=/bin/bash` is the method used here. *(Worth re-verifying on RHEL 10; standard Red Hat courseware still documents `rd.break` as valid.)*

Key steps: `init=/bin/bash`, `mount -o remount,rw /`, `passwd root`, `touch /.autorelabel`, `exec /sbin/reboot -f`

**T2 — Boot target**

```
systemctl get-default
systemctl set-default multi-user.target
```

**T3 — Bootloader**

```
vim /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg   # BIOS
# OR
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg  # UEFI
```

---

### Section 2 — Networking & Hostname

**T4 — Static IP and hostname**

```bash
nmcli con show # get interface name
sudo nmcli con add type ethernet ifname "interface-name" con-name "connection-name"
nmcli con mod "connection-name" ipv4.addresses 192.168.100.10/24 ipv4.gateway 192.168.100.1 ipv4.method manual
nmcli con mod "connection-name" ipv4.dns "8.8.8.8 1.1.1.1"
nmcli con mod "connection-name" ipv6.addresses fd00::10/64 ipv6.method manual
nmcli con up "connection-name"
hostnamectl set-hostname alpha.lab.local
```

**T5 — Firewall**

```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --add-port=8080/tcp
firewall-cmd --permanent --zone=internal --add-port=5900-5910/tcp
firewall-cmd --reload
firewall-cmd --list-all
firewall-cmd --zone=internal --list-all
```

---

### Section 3 — Users, Groups & Permissions

**T7 — Password aging**

```bash
for user in alice bob carol dave; do echo "${user}:Lab@12345"; done | sudo chpasswd
sudo chage alice -m 7 -M 60 -W 10
sudo passwd bob -n 5 -x 90 -w 14 -i 10
sudo chage carol -d 0
```

Then set `PASS_MIN_LEN 8` in `/etc/login.defs`.

**T9 — Set-GID collaborative directory**

```bash
mkdir -p /data/devshare
chown alice:developers /data/devshare
chmod 3770 /data/devshare
```

Mode `3770` = SGID (2000) + sticky (1000) + `rwxrwx---`.

**T10 — Umask**

```bash
# In /etc/profile.d/umask.sh
umask 0007
```

`umask 007` → files `666-007 = 660`, directories `777-007 = 770`.

---

### Section 5 — Software Management

**T13 — Repositories**

```bash
sudo mount /dev/sr0 /mnt/rhel10iso

# Create the repo 
sudo tee /etc/yum.repos.d/rhel10-local.repo >/dev/null <<'EOF'
[BaseOS]
name=Base OS Packages from DVD
baseurl=file:///mnt/rhel10iso/BaseOS
enabled=1
gpgcheck=0

[AppStream]
name=AppStream Packages from DVD
baseurl=file:///mnt/rhel10iso/AppStream
enabled=1
gpgcheck=0
EOF

# Verify
sudo dnf repolist
ls /mnt/rhel10iso/

# Make persist past reboot
echo '/dev/sr0  /mnt/rhel10iso  iso9660  ro,nofail  0 0' | sudo tee -a /etc/fstab

# Test persistence without reboot
sudo umount /mnt/rhel10iso 2>/dev/null
sudo mount -a
sudo dnf repolist
ls /mnt/rhel10iso/
```

**T14 — Package management**

```bash
sudo dnf install vim-enhanced tmux wget httpd -y
rpm -qc httpd
sudo dnf download --destdir /root/downloads/ nmap
# using * with sudo expands as the user not root and returns nothing.  
# Use sudo bash -c to start a root shell to run the command to see the proper expansion or type the whole filename
sudo bash -c 'rpm -K /root/downloads/nmap-*.rpm' 
sudo bash -c 'rpm -ivh /root/downloads/nmap-*.rpm'
sudo rpm -e nmap

# Verify Uninstall, use before uninstall to verify present
sudo rpm -qa nmap
```

**T15 — Package groups, Flatpak, versioned RPMs**

```bash
# Part A
sudo dnf group list
sudo dnf group info "Development Tools"
sudo dnf group install "Development Tools" -y
sudo dnf group remove "Development Tools" -y

# Part B
flatpak remotes
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak search gimp
flatpak install flathub org.gimp.GIMP -y
flatpak list
flatpak run org.gimp.GIMP
flatpak update -y
flatpak uninstall org.gimp.GIMP -y
flatpak uninstall --unused -y

# Part C
dnf list postgresql\*        # discover available versioned packages
sudo dnf install postgresql-server -y
rpm -q postgresql-server
```

> ⚠️ Legacy note (know it exists, don't rely on it): `dnf module list/enable/install/reset` still runs in RHEL 10 but prints "modularity is deprecated" and will be removed in the next major release. postgresql is no longer delivered as a module on RHEL 10, so `dnf module list postgresql` returns nothing — install the RPM directly.

---

### Section 6 — Storage

**T16 — GPT partitions**

```bash
# Open fdisk
sudo fdisk /dev/vdb

# Inside fdisk:
g          # Create GPT partition table

n          # Create vdb1
<Enter>    # Partition number 1
<Enter>    # First sector
+1G        # Size

n          # Create vdb2
<Enter>    # Partition number 2
<Enter>    # First sector
+500M      # Size

t          # Change partition type
2          # Select partition 2
19         # Linux swap

n          # Create vdb3
<Enter>    # Partition number 3
<Enter>    # First sector
+2G        # Size

p          # Verify partition layout

w          # Write changes and exit
```

```bash
# Inform the kernel of partition table changes
sudo partprobe /dev/vdb

# Verify
lsblk
sudo fdisk -l /dev/vdb
```

Expected Result:

```text
/dev/vdb1    1G    Linux filesystem
/dev/vdb2  500M    Linux swap
/dev/vdb3    2G    Linux filesystem
```

**T17 — Filesystems by UUID and LABEL**

```bash
# Create filesystems
sudo mkfs.xfs /dev/vdb1
sudo mkfs.ext4 -L DATASTORE /dev/vdb3

# Create mount points
sudo mkdir -p /mnt/xfs_data
sudo mkdir -p /mnt/ext4_data

# Get UUID of vdb1
UUID=$(sudo blkid -s UUID -o value /dev/vdb1)

# Add persistent mounts to /etc/fstab
echo "UUID=${UUID} /mnt/xfs_data xfs defaults 0 0" | sudo tee -a /etc/fstab
echo "LABEL=DATASTORE /mnt/ext4_data ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Mount all filesystems
sudo mount -a

# Verify
df -hT
lsblk -f

# Create test files
sudo touch /mnt/xfs_data/xfs_test.txt
sudo touch /mnt/ext4_data/ext4_test.txt

# Reboot and verify persistence
sudo reboot
```

After reboot:

```bash
df -hT
ls /mnt/xfs_data
ls /mnt/ext4_data
```

Expected Result:

```text
/dev/vdb1 mounted on /mnt/xfs_data (xfs) using UUID=
/dev/vdb3 mounted on /mnt/ext4_data (ext4) using LABEL=DATASTORE

/mnt/xfs_data/xfs_test.txt exists
/mnt/ext4_data/ext4_test.txt exists
```

**T18 — Swap with priority**

```bash
# Create swap signature
sudo mkswap /dev/vdb2

# Get UUID
UUID=$(sudo blkid -s UUID -o value /dev/vdb2)

# Add persistent swap entry with priority 10
echo "UUID=${UUID} none swap defaults,pri=10 0 0" | sudo tee -a /etc/fstab

# Verify fstab
tail -1 /etc/fstab

# Enable swap
sudo swapon -a

# Verify
swapon --show
free -h

# Reboot and verify persistence
sudo reboot
```

After reboot:

```bash
swapon --show
free -h
```

Expected Result:

```text
NAME      TYPE SIZE USED PRIO
/dev/vdb2 partition 500M   0B   10
```

And:

```text
Swap: 500M
```

**T19 — LVM**

```bash
# Create physical volume
sudo pvcreate /dev/vdc

# Create volume group with 16 MiB PE size
sudo vgcreate -s 16M vg_lab /dev/vdc

# Create logical volumes
sudo lvcreate -L 500M -n lv_data vg_lab
sudo lvcreate -l 25 -n lv_logs vg_lab

# Format logical volumes
sudo mkfs.xfs /dev/vg_lab/lv_data
sudo mkfs.ext4 /dev/vg_lab/lv_logs

# Create mount points
sudo mkdir -p /mnt/lv_data
sudo mkdir -p /mnt/lv_logs

# Get UUIDs
UUID_DATA=$(sudo blkid -s UUID -o value /dev/vg_lab/lv_data)
UUID_LOGS=$(sudo blkid -s UUID -o value /dev/vg_lab/lv_logs)

# Add persistent mounts
echo "UUID=${UUID_DATA} /mnt/lv_data xfs defaults 0 0" | sudo tee -a /etc/fstab
echo "UUID=${UUID_LOGS} /mnt/lv_logs ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Verify fstab
tail -2 /etc/fstab

# Mount and verify
sudo mount -a
df -hT

# Verify LVM layout
sudo pvs
sudo vgs
sudo lvs
```

Expected Result:

```text
PV: /dev/vdc     VG: vg_lab
VG PE size: 16.00 MiB
lv_data  500.00m  (XFS)   -> /mnt/lv_data
lv_logs  400.00m  (ext4)  -> /mnt/lv_logs     # 25 extents x 16 MiB
```

**T20 — Extend an LV**

```bash
# Verify free space in the volume group
sudo vgs vg_lab

# Extend LV to 1 GiB and grow filesystem in one command
sudo lvextend -L 1G -r /dev/vg_lab/lv_data

# Confirm new size
df -h /mnt/lv_data
sudo lvs
```

Expected Result:

```text
lv_data  vg_lab  1.00g   -> /mnt/lv_data (XFS)

df -h shows /mnt/lv_data ~1.0G
```

---

### Section 7 — File Systems & NFS

**T21 — NFS server**

```bash
# Install NFS utilities
sudo dnf install -y nfs-utils

# Create export directories
sudo mkdir -p /export/shared
sudo mkdir -p /export/readonly
```

**3 ways to make the /export/shared directory writable on the server (bravo):**

```bash
# Loosen permissions (not recommended for production)
sudo chmod 0777 /export/shared

# Own the dir by the squashed user on the server
sudo chown nobody:nobody /export/shared

# Set Specific user/group ownership and use root_squash in /etc/exports (recommended)
# NFS Service User Setup — Map All Clients to `nfsuser` (UID/GID 1500)

# Create the group with a specific GID
sudo groupadd -g 1500 nfsuser

# Create the user with a specific UID, primary group, no login
sudo useradd -u 1500 -g 1500 -M -s /sbin/nologin nfsuser

# Verify the IDs
id nfsuser

# Own the export directory by that service user
sudo chown -R nfsuser:nfsuser /export/shared

# Set collaborative permissions (SGID so new files inherit the group)
sudo chmod 2775 /export/shared

# Configure the export to squash everyone to UID/GID 1500
echo "/export/shared 192.168.100.0/24(rw,sync,all_squash,anonuid=1500,anongid=1500)" | sudo tee -a /etc/exports

# Add export for read-only directory
echo "/export/readonly 192.168.100.10(ro,sync,no_subtree_check)" | sudo tee -a /etc/exports

# Verify exports file
cat /etc/exports

# Enable and start the NFS server
sudo systemctl enable --now nfs-server.service

# Add permanent firewall rules
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --reload

# Re-export and confirm
sudo exportfs -rav
sudo exportfs -v
```

Expected Result:

```text
/export/shared    192.168.100.0/24(rw,sync,...)
/export/readonly  192.168.100.10(ro,sync,...)
```

**T22 — NFS client**

```bash
# Install NFS utilities (needed for the client too)
sudo dnf install -y nfs-utils

# Create mount points
sudo mkdir -p /mnt/nfs_shared
sudo mkdir -p /mnt/nfs_ro

# Add persistent NFS entries to /etc/fstab
echo "192.168.100.20:/export/shared /mnt/nfs_shared nfs _netdev 0 0" | sudo tee -a /etc/fstab
echo "192.168.100.20:/export/readonly /mnt/nfs_ro nfs _netdev 0 0" | sudo tee -a /etc/fstab

# Verify fstab
tail -2 /etc/fstab

# Mount and verify
sudo mount -a
df -hT

# Create test file on the shared (rw) mount
sudo touch /mnt/nfs_shared/from_alpha.txt
ls -l /mnt/nfs_shared
```

On bravo, confirm the file appeared:

```bash
ls -l /export/shared
```

Expected Result:

```text
192.168.100.20:/export/shared   -> /mnt/nfs_shared  (nfs4)
192.168.100.20:/export/readonly -> /mnt/nfs_ro       (nfs4)

/export/shared/from_alpha.txt   visible on bravo
```

**T23 — AutoFS**

Prerequisite — export /export/home on bravo:

```bash
# On bravo
sudo mkdir -p /export/home
sudo useradd -b /export/home autouser        # test user with home under /export/home
echo "/export/home 192.168.100.0/24(rw,sync,no_subtree_check,crossmnt,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -rav
sudo exportfs -v
```

**On alpha**

```bash
# Install autofs
sudo dnf install -y autofs

# DIRECT MAP — master entry
echo "/-  /etc/auto.direct" | sudo tee /etc/auto.master.d/direct.autofs

#  Direct map file
echo "/autodir  -rw  bravo:/export/shared" | sudo tee /etc/auto.direct

# INDIRECT MAP — master entry
echo "/mnt/autohome  /etc/auto.home" | sudo tee /etc/auto.master.d/home.autofs

# Indirect map file (& expands to the requested key/username)
echo "*  -rw  bravo:/export/home/&" | sudo tee /etc/auto.home

# Enable and start autofs
sudo systemctl enable --now autofs

# Verify service and maps
sudo systemctl status autofs
```

**Test**

```bash
# Direct map — access triggers the mount
ls /autodir
df -hT | grep autodir

# Indirect map — accessing a user's path triggers the mount
ls /mnt/autohome/autouser
df -hT | grep autohome
```

**Expected Result:**

```text
bravo:/export/shared          -> /autodir           (auto-mounted on access)
bravo:/export/home/autouser   -> /mnt/autohome/autouser (auto-mounted on access)
```

**T24 — Permission diagnostics**

```bash
# Fix /var/www/html — root:root, world-readable, not world-writable
sudo chown root:root /var/www/html
sudo chmod 755 /var/www/html

# Verify
ls -ld /var/www/html

# Create /secure/app — alice:developers, no access for others, SGID
sudo mkdir -p /secure/app
sudo chown alice:developers /secure/app
sudo chmod 2770 /secure/app

# Verify
ls -ld /secure/app


# Fix /tmp/badperms — 640, bob:developers
sudo touch /tmp/badperms
sudo chown bob:developers /tmp/badperms
sudo chmod 640 /tmp/badperms

# Verify
ls -l /tmp/badperms

# Find world-writable files under /etc and save the list
sudo find /etc -perm -o+w -type f > /root/world_writable.txt

# Verify
sudo cat /root/world_writable.txt
```

**Expected Results:**

```text
/var/www/html   drwxr-xr-x  root root
/secure/app     drwxrws---  alice developers
/tmp/badperms   -rw-r-----  bob developers
/root/world_writable.txt   contains any world-writable files found under /etc
```

---

### Section 8 — System Services, Logging & Time

**T25 — Chrony**

```bash
# Install chrony if not present
sudo dnf install -y chrony

# Add the primary NTP source to /etc/chrony.conf
# (comment out existing pool/server lines first for a clean config)
sudo sed -i 's/^pool /#pool /; s/^server /#server /' /etc/chrony.conf
echo "pool 2.rhel.pool.ntp.org iburst" | sudo tee -a /etc/chrony.conf

# Verify the line was added
grep "2.rhel.pool.ntp.org" /etc/chrony.conf

# Enable and start chronyd
sudo systemctl enable --now chronyd

# Restart to apply config changes, then verify
sudo systemctl restart chronyd
chronyc tracking
chronyc sources -v
timedatectl

# Timezone — alpha
sudo timedatectl set-timezone America/Chicago
timedatectl

# Timezone — bravo
sudo timedatectl set-timezone UTC
timedatectl
```

**T26 — Tuned**

```bash
# Install, enable, and start tuned
sudo dnf install -y tuned
sudo systemctl enable --now tuned

# List all available profiles
tuned-adm list

# Show the currently active profile
tuned-adm active

# Change active profile to throughput-performance
sudo tuned-adm profile throughput-performance

# Verify the active profile
tuned-adm active

# Create the merged custom profile 'lab-custom'
sudo mkdir -p /etc/tuned/lab-custom
sudo tee /etc/tuned/lab-custom/tuned.conf <<'EOF'
[main]
summary=Custom merged profile: virtual-guest + powersave
include=virtual-guest,powersave
EOF

# Apply lab-custom and verify
sudo tuned-adm profile lab-custom

# In RHEL 10 power-profiles-daemon (ppd) is layered on top of
# tuned and will override the profile after reboot if not set directly
echo "lab-custom" | sudo tee /etc/tuned/ppd_base_profile
sudo systemctl restart tuned
tuned-adm active

# Ensure persistence before reboot
systemctl is-enabled tuned           # 1. enabled
cat /etc/tuned/active_profile        # 2. your profile name
cat /etc/tuned/profile_mode          # 3. manual
cat /etc/tuned/ppd_base_profile      # 4. your profile name  ← RHEL 10 addition


# Reboot and verify
sudo reboot -h now

# Verify
tuned-adm active       # confirm lab-custom is current
sudo tuned-adm verify  # check applied settings match the profile (may warn on VMs)
tuned-adm list | grep lab-custom   # confirm it appears in the profile list
```

**Expected Results:**

```text
tuned-adm active  ->  Current active profile: lab-custom
```

**T27 — Process management**

```bash
# Launch three background dd processes
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &

# Identify them
ps -C dd -o pid,ni,pcpu,comm
# or watch live:
top -c            # press 'q' to quit
# or:
pidstat 1 3       # 1-sec samples, 3 times

# Grab one PID to work with
PID=$(pgrep -n dd)     # newest dd process
echo "$PID"

# Set niceness to 10 (raising nice = lower priority, allowed as user)
renice -n 10 -p "$PID"

# Set niceness to -5 (lowering nice = higher priority, requires root)
sudo renice -n -5 -p "$PID"

# Verify the nice change
ps -o pid,ni,comm -p "$PID"

# Kill all dd processes
killall dd

# Confirm none remain
pgrep -x dd || echo "no dd processes running"
ps -C dd

# Signal lifecycle on a sleep process
sleep 3600 &
SPID=$!
echo "sleep PID: $SPID"

kill -SIGSTOP "$SPID"     # pause (state T)
ps -o pid,stat,comm -p "$SPID"

kill -SIGCONT "$SPID"     # resume (state S)
ps -o pid,stat,comm -p "$SPID"

kill -SIGTERM "$SPID"     # terminate
pgrep -x sleep || echo "sleep terminated"

# Launch a niced process
nice -n 15 sleep 1000 &
ps -o pid,stat,ni,comm -p $!
```

Expected Results:

```text
Step 3:  NI = 10   (as regular user)
Step 4:  NI = -5   (root required)
Step 5:  all dd processes gone
Step 6:  STAT T (stopped) -> S (sleeping) -> process ends
Step 7:  new sleep with NI = 15
```

**T28 — Persistent journal and rsyslog**

```bash
# Configure journald for persistent storage
sudo sed -i 's/^#\?Storage=.*/Storage=persistent/' /etc/systemd/journald.conf

# Create the persistent journal directory (journald will also do this itself on restart)
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal

# Restart journald to apply
sudo systemctl restart systemd-journald

# Verify the directory exists and journald is using it
ls -ld /var/log/journal
journalctl --disk-usage

# Logs since last boot
journalctl -b

# Filter logs for the sshd service
journalctl -u sshd

# Only error-level and above
journalctl -p err

# Last 50 lines
journalctl -n 50

# Configure rsyslog to write all *.info messages to /var/log/messages.info
echo "*.info    /var/log/messages.info" | sudo tee -a /etc/rsyslog.conf

# Restart rsyslog to apply
sudo systemctl restart rsyslog

# Send a test message and verify it landed in the right log
logger "RHCSA test message from $(hostname)"
grep "RHCSA test message" /var/log/messages.info
```

Expected Results:

```text
Step 1-2:  /etc/systemd/journald.conf has Storage=persistent; /var/log/journal/ exists after restart
Step 3:    journalctl -b, -u sshd, -p err, -n 50 all return filtered output
Step 4:    /var/log/messages.info receives *.info and higher messages after rsyslog restart
Step 5:    logger test line appears in /var/log/messages.info
```

**T29 — at, cron, systemd timer**

```bash
# 1. at — one-time job in 5 minutes
# Ensure atd is running
sudo systemctl enable --now atd

# Schedule the job
echo 'echo "Scheduled at task ran" >> /var/log/at_test.log' | at now + 5 minutes

# Verify it's queued
atq
at -l              # same thing

# 2. cron — daily job for user alice at 8:00 AM
# Edit alice's crontab (as alice, or use -u as root)
sudo crontab -e -u alice

# Add this line:
0 8 * * * date >> ~/cron_test.log

# Verify:
sudo crontab -l -u alice

# 3. systemd timer — hourly script
# Create the script
sudo tee /usr/local/bin/hourly_check.sh <<'EOF'
#!/bin/bash
echo "$(date)" >> /var/log/hourly.log
EOF
sudo chmod +x /usr/local/bin/hourly_check.sh

# Create the service unit
sudo tee /etc/systemd/system/hourly-check.service <<'EOF'
[Unit]
Description=Hourly check script

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hourly_check.sh
EOF

# Create the timer unit
sudo tee /etc/systemd/system/hourly-check.timer <<'EOF'
[Unit]
Description=Run hourly-check every hour

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd, enable and start the TIMER (not the service)
sudo systemctl daemon-reload
sudo systemctl enable --now hourly-check.timer

# Verify
systemctl status hourly-check.timer
systemctl list-timers hourly-check.timer
```

Expected Results:

```text
at:      atq shows one queued job
cron:    crontab -l -u alice shows the 8:00 AM line
timer:   list-timers shows hourly-check.timer with a NEXT run time
```

---

### Section 9 — Shell Scripting

**T30 — syscheck.sh**

```bash
sudo tee /usr/local/bin/syscheck.sh <<'EOF'
#!/bin/bash

check_cpu() {
    echo "=== CPU Model ==="
    lscpu | grep -i "model name" || lscpu | grep -i "^Model"
}

check_mem() {
    echo "=== Memory ==="
    free -h
}

check_disk() {
    echo "=== Disk Usage ==="
    df -hT
}

usage() {
    echo "Usage: $0 {cpu|mem|disk|all} [more args...]" >&2
    exit 1
}

if [ "$#" -eq 0 ]; then
    usage
fi

for arg in "$@"; do
    case "$arg" in
        cpu)  check_cpu ;;
        mem)  check_mem ;;
        disk) check_disk ;;
        all)  check_cpu; check_mem; check_disk ;;
        *)    echo "Invalid argument: $arg" >&2; usage ;;
    esac
done
EOF

sudo chmod 755 /usr/local/bin/syscheck.sh

# Test each argument
syscheck.sh cpu
syscheck.sh mem
syscheck.sh disk
syscheck.sh all
syscheck.sh              # no arg -> usage, exit 1
syscheck.sh badarg       # invalid -> usage, exit 1
echo "Exit code: $?"     # should be 1 for bad/no arg
```

**T31 — bulk_users.sh**

```bash
# Create the username list
sudo tee /root/userlist.txt <<'EOF'
testuser1
testuser2
testuser3
testuser4
testuser5
EOF

# Create the script
sudo tee /usr/local/bin/bulk_users.sh <<'EOF'
#!/bin/bash

for user in $(cat /root/userlist.txt); do
    if id "$user" &>/dev/null; then
        echo "User $user already exists"
    else
        useradd "$user"
        echo "$user" | passwd --stdin "$user" &>/dev/null
        echo "User $user created successfully"
    fi
done
EOF

sudo chmod +x /usr/local/bin/bulk_users.sh

# Run it (needs root to create users)
sudo /usr/local/bin/bulk_users.sh

# Run again to confirm the "already exists" branch
sudo /usr/local/bin/bulk_users.sh

# Verify
for u in $(cat /root/userlist.txt); do id "$u"; done
```

**T32 — etcbackup.sh**

```bash
# Create the backup script
sudo tee /root/etcbackup.sh <<'EOF'
#!/bin/bash

BACKUP_DIR="/root/backups"
DATE=$(date +%F)
ARCHIVE="etc_backup_${DATE}.tar.gz"
LOG="/var/log/etcbackup.log"

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

# Create the compressed archive
tar czf "${BACKUP_DIR}/${ARCHIVE}" /etc 2>/dev/null

# Remove backups older than 7 days
find "$BACKUP_DIR" -name "etc_backup_*.tar.gz" -mtime +7 -delete

# Log the result
echo "$(date '+%F %T') - Created ${ARCHIVE}" >> "$LOG"
EOF

sudo chmod +x /root/etcbackup.sh

# Test it manually
sudo /root/etcbackup.sh
ls -l /root/backups/
sudo cat /var/log/etcbackup.log

# Schedule via root's crontab: 11:30 PM every night EXCEPT Sunday
sudo crontab -e

# Add this line:
30 23 * * 1-6 /root/etcbackup.sh

# Verify:

sudo crontab -l
```

In cron's day-of-week field, `0` (and `7`) is Sunday, so `1-6` is Monday through Saturday.

---

### Section 10 — SELinux

**T34 — SELinux ports and booleans**

```bash
semanage port -a -t http_port_t -p tcp 8181
setsebool -P httpd_can_network_connect on
setsebool -P httpd_enable_homedirs on
restorecon -v /var/www/html/hosts.txt
```

---

### Section 11 — Containers

**T35 — Quadlet**

```ini
# ~/.config/containers/systemd/alice-web.container
[Unit]
Description=Alice Web Container
After=local-fs.target

[Container]
Image=registry.access.redhat.com/ubi10/httpd-24
PublishPort=8080:8080
Volume=%h/web_content:/var/www/html:Z
ContainerName=alice_web

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
loginctl enable-linger alice
systemctl --user daemon-reload
systemctl --user enable --now alice-web.service
```

---

## 🔑 Key Commands Quick Reference

### Storage

```bash
lsblk / fdisk / parted / sfdisk -d   # fdisk handles GPT natively; gdisk is a separate package
pvcreate / vgcreate / lvcreate / lvextend -r
mkfs.xfs / mkfs.ext4 / mkfs.vfat / mkswap
blkid / findfs LABEL=xxx
mount -a  # test fstab BEFORE you reboot
```

### SELinux

```bash
getenforce / setenforce / sestatus
ls -Z / ps -Z
chcon -t TYPE file           # temporary
semanage fcontext -a -t TYPE '/path(/.*)?'
restorecon -Rv /path         # apply policy
semanage port -a -t TYPE -p tcp PORT
getsebool -a / setsebool -P NAME on|off
ausearch -m avc -ts recent   # check denials
```

### Containers (RHEL 10 — Quadlets)

```bash
podman pull / run / ps / stop / rm / rmi
podman inspect IMAGE
podman exec -it NAME bash
# Quadlet files: ~/.config/containers/systemd/*.container
systemctl --user daemon-reload
systemctl --user enable --now service-name.service
loginctl enable-linger USERNAME
```

### Systemd

```bash
systemctl list-units --type=service
systemctl status/start/stop/enable/disable
journalctl -u SERVICE -b -p err
systemctl get-default / set-default
```

---

## 📚 Study References for Weak Areas

Based on your current objective tracker, focus on:

| Priority  | Topic                                  | Resource                                                                                   |
| --------- | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| 🔴 High   | Storage (LVM, partitions, filesystems) | `man lvm`, `man fstab`, Sander van Vugt RHCSA 9                                        |
| 🔴 High   | SELinux                                | `man semanage`, `man restorecon`, audit2why                                            |
| 🔴 High   | Users/Groups/sudo                      | `man useradd`, `man sudoers`, `man chage`                                            |
| 🟡 Medium | Shell scripting                        | GNU Bash manual,`man test`                                                               |
| 🟡 Medium | NFS + AutoFS                           | `man exports`, `man auto.master`                                                       |
| 🟡 Medium | Containers (Quadlets)                  | [Podman Quadlet Docs](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) |
| 🟢 Lower  | Networking/firewalld                   | `man nmcli`, `man firewall-cmd`                                                        |

---

*Practice exam created 2026-05-12 based on RHEL 10 EX200 objectives*
*Sources: Red Hat EX200 objectives page, aggressiveHiker/rhcsa9, soficx/rhcsa*
*Restructured 2026-09-09: inline solutions moved to the answer key at the end so the exam can be re-run cold.*
