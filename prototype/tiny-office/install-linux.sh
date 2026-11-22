#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    set -- "$script_dir"/tiny-office_*_amd64.deb
fi
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf 'Usage: %s [path/to/tiny-office_*_amd64.deb]\n' "$0" >&2
    exit 2
fi

package=$(realpath -- "$1")
if [ "$(dpkg-deb --field "$package" Package)" != tiny-office ]; then
    printf 'Select a Tiny Office DEB package.\n' >&2
    exit 2
fi
if [ "$(id -u)" -eq 0 ]; then
    exec apt-get install "$package"
fi
exec sudo apt-get install "$package"
