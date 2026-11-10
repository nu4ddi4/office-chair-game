#!/bin/sh
# Remove a per-user install made by install.sh. Saved progress is kept.
set -eu
data=${XDG_DATA_HOME:-$HOME/.local/share}
rm -rf "$data/office-chair-chaos"
rm -f "$HOME/.local/bin/office-chair-chaos" "$data/applications/office-chair-chaos.desktop" "$data/icons/hicolor/256x256/apps/office-chair-chaos.png"
echo "Removed. Saved progress stays in $data/OfficeChairChaos."
