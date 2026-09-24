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
