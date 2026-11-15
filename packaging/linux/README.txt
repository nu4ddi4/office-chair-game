Office Chair Chaos (김 대리, 나 좀 밀어봐) for Linux x86_64

Debian / Ubuntu (amd64):
  sudo apt install ./office-chair-chaos_<version>_amd64.deb
  Then start "Office Chair Chaos" from the app menu, or run: office-chair-chaos
  Remove with: sudo apt remove office-chair-chaos

Portable (any distribution):
  tar xf OfficeChairChaos-<version>-linux-x86_64.tar.gz
  ./OfficeChairChaos/OfficeChairChaos.x86_64
  Optional per-user install: ./OfficeChairChaos/install.sh (remove with uninstall.sh)

Saved progress lives in ~/.local/share/OfficeChairChaos and is never removed by
uninstalling. Graphics need Vulkan or OpenGL 3.3 drivers (Mesa is fine).
Updates are not installed automatically on Linux; the in-game update screen opens
the release page so you can download the new package.
