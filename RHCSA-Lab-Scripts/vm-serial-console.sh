#!/usr/bin/env bash
# vm-serial-console.sh — runs INSIDE a guest (virt-customize --run) so 'virsh console'
# shows the GRUB menu, kernel/boot messages, emergency/rescue shells and a login prompt
set -euo pipefail

ARGS='console=tty0 console=ttyS0,115200'   # ttyS0 last = /dev/console, so emergency/rescue shells land on serial

# Kernel args: current BLS entries now, GRUB_CMDLINE_LINUX for future kernels / grub2-mkconfig
grubby --update-kernel=ALL --args="${ARGS}"
grep -q 'console=ttyS0' /etc/default/grub ||
  sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ${ARGS}\"/" /etc/default/grub

# GRUB menu on both the graphical console and serial (needed for the GRUB 'e' break-in tasks)
sed -i '/^GRUB_TERMINAL\(_INPUT\|_OUTPUT\)\?=/d; /^GRUB_SERIAL_COMMAND=/d' /etc/default/grub
cat >> /etc/default/grub <<'EOF'
GRUB_TERMINAL_INPUT="console serial"
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
EOF
grub2-mkconfig -o /boot/grub2/grub.cfg   # same path on BIOS and UEFI (EFI grub.cfg is a stub on RHEL 9+)

systemctl enable serial-getty@ttyS0.service
