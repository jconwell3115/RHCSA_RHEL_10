---
title: RHCSA Practice Exam - RHEL 10
tags: [certifications, rhcsa, rhel10, practice, linux]
created: 2026-05-12
---
# 🧪 RHCSA Practice Exam — RHEL 10 (EX200)

> **Format:** Performance-based | **Time Limit:** 2.5 hours | **Pass Score:** ~70%
>
> All configurations **must persist after reboot** without intervention.
>
> You may use `man`, `info`, and `/usr/share/doc` — no internet access on exam day.

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
- Or mount the RHEL 10 ISO and configure a local repo (covered in Task 9)

---

## 📋 Exam Instructions

Read carefully before beginning:

1. All tasks must be completed on the correct host (alpha or bravo)
2. All configurations must survive a `reboot` — test this for critical tasks
3. Partial credit is not given on the real exam — complete each task fully
4. Work methodically; a wrong fstab entry can break boot

---

## 🚀 PRACTICE EXAM — 35 TASKS

---

### SECTION 1: System Recovery & Boot Management

---

**Task 1 — Break Into bravo and Reset Root Password** *(bravo)*

> Objective: Interrupt the boot process in order to gain access to a system

The root password on `rhel10-bravo` is unknown. Break into the system using the `init=/bin/bash` method, reset the root password to `RedHat10!`, and ensure SELinux labels are updated before the next boot. Reboot and confirm login.

> rd.break is no longer a valid breakin method, it drops to an emergency mode not shell.  init=/bin/bash is the only method

**Hint:** `init=/bin/bash`, `mount -o remount,rw /`, `passwd root`, `touch /.autorelabel`, `exec /sbin/reboot -f`

---

**Task 2 — Configure Boot Target** *(bravo)*

> Objective: Boot systems into different targets manually

After breaking into bravo, confirm it is currently booting to `graphical.target`. Change the default boot target to `multi-user.target`. Reboot and verify the system boots without a GUI.

```
systemctl get-default
systemctl set-default multi-user.target
```

---

**Task 3 — Modify the Bootloader** *(alpha)*

> Objective: Modify the system bootloader

Edit the GRUB configuration on `rhel10-alpha` with the following changes:

- Set `GRUB_TIMEOUT=10`
- Add the line: `GRUB_TIMEOUT_STYLE=countdown`
- Append `quiet` to the end of `GRUB_CMDLINE_LINUX`

Regenerate the GRUB config and reboot to verify.

```
vim /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg   # BIOS
# OR
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg  # UEFI
```

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

Add entries for both hosts to `/etc/hosts` on both systems. Confirm connectivity between nodes by hostname.

```bash
nmcli con show # get interface name
sudo nmcli con add type thernet ifname "interface-name" con-name "connection-name"
nmcli con mod "connection-name" ipv4.addresses 192.168.100.10/24 ipv4.gateway 192.168.100.1 ipv4.method manual
nmcli con mod "connection-name" ipv4.dns "8.8.8.8 1.1.1.1"
nmcli con mod "connection-name" ipv6.addresses fd00::10/64 ipv6.method manual
nmcli con up "connection-name"
hostnamectl set-hostname alpha.lab.local
```

---

**Task 5 — Configure Firewall for SSH and HTTP** *(alpha)*

> Objective: Restrict network access using firewall-cmd/firewalld

On `alpha`:

- Ensure `sshd` is permanently allowed in the `public` zone
- Permanently allow HTTP traffic (port 80/tcp) in the `public` zone
- Add a runtime-only rule allowing port `8080/tcp`
- Permanently allow TCP ports `5900-5910` in the `internal` zone
- Reload the firewall and confirm rules persist

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

- Set the password for all users created in Task 6 to `Lab@12345`
  - `for user in alice bob carol dave; do echo "${user}:Lab@12345"; done | sudo chpasswd`
- Using `chage`, configure `alice` with: minimum 7 days, maximum 60 days, warn 10 days
  - `sudo chage alice -m 7 -M 60 -W 10`
- Using `passwd`, configure `bob` with: minimum 5 days, maximum 90 days, warn 14 days, inactive 10 days
  - `sudo passwd bob -n 5 -x 90 -w 14 -i 10`
- Force `carol` to change her password on next login
  - `sudo chage carol -d 0`qq
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

```bash
mkdir -p /data/devshare
chown alice:developers /data/devshare
chmod 3770 /data/devshare
```

---

**Task 10 — Standard File Permissions & Umask** *(both nodes)*

> Objective: Manage default file permissions, List/set/change standard ugo/rwx permissions

- On `alpha`, configure the system-wide umask so all newly created files default to `660` and directories default to `770`. Make this persistent for all users.
- On `bravo`, apply the same setting.
- Verify by creating a test file and directory as a regular user.

```bash
# In /etc/profile.d/umask.sh
umask 0007
```

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

Ensure `PermitRootLogin yes` is set in `/etc/ssh/sshd_config` on bravo.

---

**Task 12 — Secure File Transfer** *(alpha → bravo)*

> Objective: Securely transfer files between systems

- Use `scp` to copy `/etc/hosts` from alpha to `/tmp/hosts_from_alpha` on bravo
- Use `rsync` to synchronize the `/etc/sysconfig/` directory from alpha to `/tmp/sysconfig_backup/` on bravo
- Use `sftp` interactively to upload `/etc/motd` from alpha to bravo's `/tmp/`

---

### SECTION 5: Software Management

---

**Task 13 — Configure Repositories** *(alpha)*

> Objective: Install and update software packages from Red Hat CDN, remote repo, or local file system

Configure a local YUM/DNF repository from the RHEL 10 installation ISO:

1. Mount the RHEL 10 ISO at `/mnt/rhel10iso`
2. Create a repo file `/etc/yum.repos.d/rhel10-local.repo` with:
   - `[BaseOS]` section pointing to `file:///mnt/rhel10iso/BaseOS`
   - `[AppStream]` section pointing to `file:///mnt/rhel10iso/AppStream`
   - Both enabled, `gpgcheck=0`
3. Verify with `dnf repolist`

Then (if connected): also add the EPEL repository for RHEL 10.

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

```bash
dnf install vim-enhanced tmux wget httpd -y
rpm -qc httpd
dnf download --destdir /root/downloads/ nmap
rpm -K /root/downloads/nmap-*.rpm
rpm -ivh /root/downloads/nmap-*.rpm
rpm -e nmap
```

---

**Task 15 — DNF Module Streams** *(alpha)*

> Objective: Install and update software packages from remote repository

- List all available module streams for `postgresql`
- Enable and install `postgresql` stream version 16
- Verify the installation
- Switch to a different stream (if available) or reset the module
- Remove the postgresql module

```bash
dnf module list postgresql
dnf module enable postgresql:16
dnf module install postgresql:16
dnf module remove postgresql:16
dnf module reset postgresql
```

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

```bash
lvextend -L 1G -r /dev/vg_lab/lv_data
```

---

### SECTION 7: File Systems & NFS

---

**Task 21 — Configure NFS Server** *(bravo)*

> Objective: Mount and unmount network file systems using NFS

On `bravo` (NFS server):

1. Install `nfs-utils`
2. Create directories `/export/shared` and `/export/readonly`
3. Add entries to `/etc/exports`:
   - `/export/shared` — read/write for `192.168.100.0/24`
   - `/export/readonly` — read-only for `192.168.100.10`
4. Start and enable `nfs-server.service`
5. Add permanent firewall rules for `nfs`, `mountd`, `rpc-bind`
6. Confirm exports with `exportfs -v`

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

```bash
# /etc/auto.master.d/direct.autofs
/-  /etc/auto.direct

# /etc/auto.direct
/autodir  -rw  bravo:/export/shared

# /etc/auto.master.d/home.autofs
/mnt/autohome  /etc/auto.home

# /etc/auto.home
*  -rw  bravo:/export/home/&
```

---

**Task 24 — File Permission Diagnostics** *(alpha)*

> Objective: Diagnose and correct file permission problems

The following files and directories have incorrect permissions. Fix them:

1. `/var/www/html/` — should be owned by `root:root`, world-readable, but not world-writable
2. Create `/secure/app/` — owned by `alice:developers`, no access for others, SGID set
3. A file `/tmp/badperms` exists with permissions `777` — change to `640`, owner `bob`, group `developers`
4. Find all world-writable files under `/etc` and report them (save list to `/root/world_writable.txt`)

```bash
find /etc -perm -o+w -type f > /root/world_writable.txt
```

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

```bash
# /etc/systemd/journald.conf
[Journal]
Storage=persistent
```

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

```bash
# /root/userlist.txt
testuser1
testuser2
testuser3
testuser4
testuser5
```

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

```bash
semanage port -a -t http_port_t -p tcp 8181
setsebool -P httpd_can_network_connect on
setsebool -P httpd_enable_homedirs on
restorecon -v /var/www/html/hosts.txt
```

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
7. Create a **Podman Quadlet** to run the container as a user systemd service that starts at login:

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

8. Enable user lingering for `alice`: `loginctl enable-linger alice`
9. Reload the user daemon and start the service:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now alice-web.service
   ```
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
| 15 | DNF module stream management              | —          | [ ]  |
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

## 🔑 Key Commands Quick Reference

### Storage

```bash
lsblk / fdisk / gdisk / parted
pvcreate / vgcreate / lvcreate / lvextend -r
mkfs.xfs / mkfs.ext4 / mkfs.vfat / mkswap
blkid / findfs LABEL=xxx
mount -a  # test fstab
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
|           |                                        |                                                                                            |

---

*Practice exam created 2026-05-12 based on RHEL 10 EX200 objectives*
*Sources: Red Hat EX200 objectives page, aggressiveHiker/rhcsa9, soficx/rhcsa*
