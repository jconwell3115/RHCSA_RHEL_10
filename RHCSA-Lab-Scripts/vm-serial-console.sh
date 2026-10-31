#!/usr/bin/env bash
# vm-serial-console.sh — runs INSIDE a guest (virt-customize --run) so 'virsh console'
# shows the GRUB menu, kernel/boot messages and a login prompt
set -euo pipefail

ARGS='console=ttyS0,115200 console=tty0'   # tty0 last = /dev/console, so break-in/emergency/rescue shells land on the graphical console, as on the exam

# Kernel args: current BLS entries now, GRUB_CMDLINE_LINUX for future kernels / grub2-mkconfig
# Strip existing console= first (a kickstart golden may already have one) so the order above always wins
grubby --update-kernel=ALL --remove-args="console=tty0 console=ttyS0,115200"
grubby --update-kernel=ALL --args="${ARGS}"
sed -i -E "/^GRUB_CMDLINE_LINUX=/{s/ *console=[^ \"]*//g; s/\"\$/ ${ARGS}\"/; s/=\" /=\"/}" /etc/default/grub

# GRUB menu on both the graphical console and serial (needed for the GRUB 'e' break-in tasks)
sed -i '/^GRUB_TERMINAL\(_INPUT\|_OUTPUT\)\?=/d; /^GRUB_SERIAL_COMMAND=/d' /etc/default/grub
cat >> /etc/default/grub <<'EOF'
GRUB_TERMINAL_INPUT="console serial"
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
EOF
grub2-mkconfig -o /boot/grub2/grub.cfg   # same path on BIOS and UEFI (EFI grub.cfg is a stub on RHEL 9+)

systemctl enable serial-getty@ttyS0.service
