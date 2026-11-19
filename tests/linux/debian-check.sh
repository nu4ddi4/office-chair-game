#!/bin/bash
# Install, run and purge the DEB inside a fresh Debian/Ubuntu container.
# docker run --rm -v "$PWD:/repo:ro" debian:bookworm-slim bash /repo/tests/linux/debian-check.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
dist=/repo/chaos-dist-linux
smoke=(--headless --audio-driver Dummy --fixed-fps 120 -- --chaos-test --mission 1 --package-smoke)
apt-get update -qq
previous=/repo/previous-deb/office-chair-chaos_0.1.2_amd64.deb
if [[ -f "$previous" ]]; then
    apt-get install -y -qq --no-install-recommends "$previous"
    [[ "$(dpkg-query -W -f='${Version}' office-chair-chaos)" == 0.1.2 ]]
fi
save_dir="${XDG_DATA_HOME:-$HOME/.local/share}/OfficeChairChaos"
mkdir -p "$save_dir"
printf 'preserve-progress\n' > "$save_dir/deb-save-preservation.txt"
package=("$dist"/office-chair-chaos_*_amd64.deb)
apt-get install -y -qq --no-install-recommends "${package[0]}" tar gzip
[[ "$(dpkg-query -W -f='${Version}' office-chair-chaos)" == "$(dpkg-deb -f "${package[0]}" Version)" ]]
dpkg-query -W -f='${Status}\n' office-chair-chaos | grep -Fxq 'install ok installed'
test -f /usr/share/applications/office-chair-chaos.desktop
test -f /usr/share/icons/hicolor/256x256/apps/office-chair-chaos.png
test -f /usr/share/doc/office-chair-chaos/copyright
cmp /opt/office-chair-chaos/LICENSES.txt /usr/share/doc/office-chair-chaos/copyright
grep -Fxq 'preserve-progress' "$save_dir/deb-save-preservation.txt"
timeout 60 office-chair-chaos "${smoke[@]}" 2>&1 | tee /tmp/deb-smoke.log
grep -q 'CHAOS_PACKAGE_SMOKE {"passed":true}' /tmp/deb-smoke.log
tar -xzf "$dist"/OfficeChairChaos-*-linux-x86_64.tar.gz -C /tmp
cmp /opt/office-chair-chaos/OfficeChairChaos.x86_64 /tmp/OfficeChairChaos/OfficeChairChaos.x86_64
timeout 60 /tmp/OfficeChairChaos/OfficeChairChaos.x86_64 "${smoke[@]}" 2>&1 | tee /tmp/tar-smoke.log
grep -q 'CHAOS_PACKAGE_SMOKE {"passed":true}' /tmp/tar-smoke.log
apt-get purge -y -qq office-chair-chaos
test ! -e /usr/bin/office-chair-chaos
test ! -e /opt/office-chair-chaos/OfficeChairChaos.x86_64
test ! -e /usr/share/applications/office-chair-chaos.desktop
grep -Fxq 'preserve-progress' "$save_dir/deb-save-preservation.txt"
echo "DEBIAN_CHECK passed on $(. /etc/os-release && echo "$PRETTY_NAME")"
