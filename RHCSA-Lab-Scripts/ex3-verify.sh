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
