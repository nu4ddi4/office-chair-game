#!/bin/bash
# Install the built RPM in a Fedora container, run the installed game and the
# portable archive headless, then remove the package.
# Usage (from the repository root, after scripts/build-linux.py --rpm):
#   docker run --rm -v "$PWD:/repo:ro" fedora:latest bash /repo/tests/linux/fedora-check.sh
set -euo pipefail
dist=/repo/chaos-dist-linux
smoke=(--headless --audio-driver Dummy --fixed-fps 120 -- --chaos-test --mission 1 --package-smoke)
dnf install -y -q tar gzip "$dist"/office-chair-chaos-*.x86_64.rpm
rpm -q office-chair-chaos
test -f /usr/share/applications/office-chair-chaos.desktop
test -f /usr/share/icons/hicolor/256x256/apps/office-chair-chaos.png
office-chair-chaos "${smoke[@]}" 2>&1 | tee /tmp/rpm-smoke.log
grep -q 'CHAOS_PACKAGE_SMOKE {"passed":true}' /tmp/rpm-smoke.log
tar -xzf "$dist"/OfficeChairChaos-*-linux-x86_64.tar.gz -C /tmp
/tmp/OfficeChairChaos/OfficeChairChaos.x86_64 "${smoke[@]}" 2>&1 | tee /tmp/tar-smoke.log
grep -q 'CHAOS_PACKAGE_SMOKE {"passed":true}' /tmp/tar-smoke.log
dnf remove -y -q office-chair-chaos
test ! -e /usr/bin/office-chair-chaos
echo "FEDORA_CHECK passed on $(. /etc/os-release && echo "$PRETTY_NAME")"
