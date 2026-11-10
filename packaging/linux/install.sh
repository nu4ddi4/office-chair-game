#!/bin/sh
# Install the portable build for the current user (no root needed).
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
target="$data/office-chair-chaos"
mkdir -p "$target" "$HOME/.local/bin" "$data/applications" "$data/icons/hicolor/256x256/apps"
cp "$here/OfficeChairChaos.x86_64" "$here/LICENSES.txt" "$target/"
chmod 0755 "$target/OfficeChairChaos.x86_64"
printf '#!/bin/sh\nexec "%s/OfficeChairChaos.x86_64" "$@"\n' "$target" > "$HOME/.local/bin/office-chair-chaos"
chmod 0755 "$HOME/.local/bin/office-chair-chaos"
cp "$here/office-chair-chaos.png" "$data/icons/hicolor/256x256/apps/"
sed "s|^Exec=.*|Exec=$HOME/.local/bin/office-chair-chaos|" "$here/office-chair-chaos.desktop" > "$data/applications/office-chair-chaos.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" || true
echo "Installed. Launch 'Office Chair Chaos' from the app menu or run: office-chair-chaos"
