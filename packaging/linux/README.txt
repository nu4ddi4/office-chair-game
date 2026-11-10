Office Chair Chaos (김 대리, 나 좀 밀어봐) for Linux x86_64

Fedora / RHEL (recommended):
  sudo dnf install ./office-chair-chaos-<version>-1.x86_64.rpm
  Then start "Office Chair Chaos" from the app menu, or run: office-chair-chaos
  Remove with: sudo dnf remove office-chair-chaos

Portable (any distribution):
  tar xf OfficeChairChaos-<version>-linux-x86_64.tar.gz
  ./OfficeChairChaos/OfficeChairChaos.x86_64
  Optional per-user install: ./OfficeChairChaos/install.sh (remove with uninstall.sh)

Saved progress lives in ~/.local/share/OfficeChairChaos and is never removed by
uninstalling. Graphics need Vulkan or OpenGL 3.3 drivers (Mesa is fine).
Updates are not installed automatically on Linux; the in-game update screen opens
the release page so you can download the new package.
