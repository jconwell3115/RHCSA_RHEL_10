#!/usr/bin/env bash
# ex2-seed-t24.sh — build the broken /opt/finance tree for Exam 2 Task 24. Run with sudo on charlie.
# Safe to re-run: it resets the tree to the broken state every time.
set -euo pipefail

rm -rf /opt/finance
mkdir -p /opt/finance/{reports,bin,private}
printf '#!/bin/bash\necho report\n' > /opt/finance/bin/run_report.sh
echo "Q3 totals" > /opt/finance/reports/q3.txt

# Every item starts wrong: owner root:root, no SGID/SUID, bad modes
chown -R root:root /opt/finance
chmod 0777 /opt/finance/reports            # should be SGID, group ops
chmod 0666 /opt/finance/bin/run_report.sh  # should be 4754, owner gina
chmod 0755 /opt/finance/private            # should be 0700, gina:gina
chmod 0000 /opt/finance                    # should be 2750, gina:ops (do this last)

rm -f /root/suid_list.txt

echo "T24 seeded: /opt/finance is 000 root:root; reports, run_report.sh and private all wrong."
