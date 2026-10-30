#!/usr/bin/env bash
# ex3-seed-echo.sh — runs INSIDE rhel10-echo as root (rebuild-rhcsa-labs.sh pipes it over SSH)
# Seeds Exam 3 Task 4 (broken labdata.service) and Task 33 (two SELinux violations)
set -euo pipefail

# --- Task 4: a unit that will fail on boot ---
cat > /etc/systemd/system/labdata.service <<'EOF'
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
systemctl daemon-reload
systemctl enable labdata.service

# --- Task 33: httpd pre-configured into TWO SELinux violations ---
# Install from the attached DVD (clones are sysprepped, so no CDN subscription), via a
# throwaway repo that leaves no .repo file behind for Task 17
mkdir -p /mnt/seed-dvd
mount -o ro /dev/sr0 /mnt/seed-dvd
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
dnf install -y --disablerepo='*' \
  --repofrompath=seed-baseos,file:///mnt/seed-dvd/BaseOS \
  --repofrompath=seed-appstream,file:///mnt/seed-dvd/AppStream \
  httpd policycoreutils-python-utils setroubleshoot-server
umount /mnt/seed-dvd
rmdir /mnt/seed-dvd
dnf clean all

mkdir -p /srv/intranet
echo "Echo Intranet OK" > /srv/intranet/index.html
cat > /etc/httpd/conf.d/intranet.conf <<'EOF'
Listen 8404
<VirtualHost *:8404>
    DocumentRoot /srv/intranet
    <Directory /srv/intranet>
        Require all granted
    </Directory>
</VirtualHost>
EOF
# Deliberately do NOT label /srv/intranet and do NOT label port 8404.
systemctl enable httpd
firewall-cmd --permanent --add-port=8404/tcp && firewall-cmd --reload
