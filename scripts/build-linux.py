#!/usr/bin/env python3
"""Build the Linux x86_64 game: a portable tar.gz and an RPM for Fedora/RHEL.

python3 scripts/build-linux.py --godot godot [--verify] [--rpm]
--verify runs the exported binary headless (Linux host only) and requires its
runtime check to pass. --rpm needs rpmbuild (dnf install rpm-build, or apt install rpm).
"""
import argparse
import hashlib
import platform
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'chaos-dist-linux'
PACKAGING = ROOT / 'packaging/linux'
BINARY = 'OfficeChairChaos.x86_64'
NAME = 'office-chair-chaos'
SMOKE = ['--headless', '--audio-driver', 'Dummy', '--fixed-fps', '120',
         '--', '--chaos-test', '--mission', '1', '--package-smoke']

SPEC = """\
%global debug_package %{{nil}}
%global __os_install_post %{{nil}}
%global _build_id_links none
Name:           {name}
Version:        {version}
Release:        1
Summary:        Office chair physics comedy (김 대리, 나 좀 밀어봐)
License:        LicenseRef-OfficeChairChaos
URL:            https://github.com/nu4ddi4/office-chair-game
ExclusiveArch:  x86_64
Recommends:     mesa-dri-drivers
Recommends:     vulkan-loader
Recommends:     libXcursor
Recommends:     libXinerama
Recommends:     libXrandr
Recommends:     libXi
Recommends:     alsa-lib
Recommends:     pulseaudio-libs

%description
A physics ragdoll employee pushes the boss across the office on a wheeled chair
without spilling his coffee. Single player, keyboard and mouse.

%install
mkdir -p %{{buildroot}}/opt/{name} %{{buildroot}}%{{_bindir}} %{{buildroot}}%{{_datadir}}/applications %{{buildroot}}%{{_datadir}}/icons/hicolor/256x256/apps
install -m 0755 %{{_sourcedir}}/{binary} %{{buildroot}}/opt/{name}/{binary}
install -m 0644 %{{_sourcedir}}/LICENSES.txt %{{buildroot}}/opt/{name}/LICENSES.txt
printf '#!/bin/sh\\nexec /opt/{name}/{binary} "$@"\\n' > %{{buildroot}}%{{_bindir}}/{name}
chmod 0755 %{{buildroot}}%{{_bindir}}/{name}
install -m 0644 %{{_sourcedir}}/{name}.desktop %{{buildroot}}%{{_datadir}}/applications/{name}.desktop
install -m 0644 %{{_sourcedir}}/{name}.png %{{buildroot}}%{{_datadir}}/icons/hicolor/256x256/apps/{name}.png

%files
/opt/{name}
%{{_bindir}}/{name}
%{{_datadir}}/applications/{name}.desktop
%{{_datadir}}/icons/hicolor/256x256/apps/{name}.png
"""


def run(command, **kwargs):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding='utf-8', errors='replace', timeout=900, **kwargs)
    print(result.stdout, end='')
    if result.returncode or re.search(r'(SCRIPT ERROR|Parse Error|^ERROR:)', result.stdout, re.M):
        raise RuntimeError('Command failed: ' + ' '.join(map(str, command[:3])))
    return result.stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--rpm', action='store_true')
    args = parser.parse_args()
    if not run([args.godot, '--version']).strip().startswith('4.7.2.stable'):
        raise RuntimeError('Use Godot 4.7.2 stable')
    version = re.search(r'^config/version="([^"]+)"', (ROOT/'godot/project.godot').read_text(encoding='utf-8'), re.M).group(1)
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()
    run([args.godot, '--headless', '--path', 'godot', '--export-release', 'Linux'])
    binary = DIST / BINARY
    if binary.read_bytes()[:4] != b'\x7fELF':
        raise RuntimeError('Expected a Linux executable')
    binary.chmod(0o755)
    sections = [('Asset credits', ROOT/'godot/assets/credits.txt'),
                ('Engine and bundled components', ROOT/'godot/LICENSES.txt'),
                ('Noto Sans KR font', ROOT/'godot/assets/fonts/OFL.txt')]
    licenses = DIST / 'LICENSES.txt'
    licenses.write_text('\n\n'.join(title+'\n'+'='*len(title)+'\n'+path.read_text(encoding='utf-8')
                                     for title, path in sections), encoding='utf-8')
    if args.verify:
        if platform.system() != 'Linux':
            raise RuntimeError('--verify requires a Linux host')
        raw = run([str(binary), *SMOKE])
        if 'CHAOS_PACKAGE_SMOKE {"passed":true}' not in raw:
            raise RuntimeError('Exported game did not pass its runtime check')
    outputs = []
    # Portable archive: one folder with the game, notices, launcher files and installers.
    archive = DIST / f'OfficeChairChaos-{version}-linux-x86_64.tar.gz'
    with tarfile.open(archive, 'w:gz') as tar:
        def add(path, name, mode):
            info = tar.gettarinfo(str(path), 'OfficeChairChaos/'+name)
            info.mode = mode; info.uid = info.gid = 0; info.uname = info.gname = 'root'
            with open(path, 'rb') as handle:
                tar.addfile(info, handle)
        add(binary, BINARY, 0o755)
        add(licenses, 'LICENSES.txt', 0o644)
        for name, mode in [('README.txt', 0o644), (NAME+'.desktop', 0o644), (NAME+'.png', 0o644),
                           ('install.sh', 0o755), ('uninstall.sh', 0o755)]:
            add(PACKAGING/name, name, mode)
    outputs.append(archive)
    if args.rpm:
        if shutil.which('rpmbuild') is None:
            raise RuntimeError('rpmbuild is required for --rpm')
        with tempfile.TemporaryDirectory() as temp:
            top = Path(temp)
            sources = top / 'SOURCES'; sources.mkdir()
            shutil.copy2(binary, sources/BINARY)
            shutil.copy2(licenses, sources/'LICENSES.txt')
            shutil.copy2(PACKAGING/(NAME+'.desktop'), sources)
            shutil.copy2(PACKAGING/(NAME+'.png'), sources)
            spec = top / (NAME+'.spec')
            spec.write_text(SPEC.format(name=NAME, version=version, binary=BINARY), encoding='utf-8')
            run(['rpmbuild', '-bb', '--define', f'_topdir {top}', str(spec)])
            built = sorted((top/'RPMS').rglob('*.rpm'))
            if len(built) != 1:
                raise RuntimeError('Expected exactly one RPM')
            package = DIST / built[0].name
            shutil.copy2(built[0], package)
            outputs.append(package)
    outputs.append(licenses)
    (DIST/'SHA256SUMS-linux.txt').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in outputs), encoding='utf-8')
    print('Linux build:', ', '.join(p.name for p in outputs), 'version', version)


if __name__ == '__main__':
    main()
