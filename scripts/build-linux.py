#!/usr/bin/env python3
"""Build the Linux x86_64 game: a portable tar.gz and a Debian/Ubuntu .deb.

python3 scripts/build-linux.py --godot godot [--verify] [--deb]
--verify runs the exported binary headless (Linux host only) and requires its
runtime check to pass. --deb needs dpkg-deb (provided by dpkg on Debian/Ubuntu).
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

CONTROL = """\
Package: {name}
Version: {version}
Architecture: amd64
Maintainer: Office Chair Chaos contributors <95563468+nu4ddi4@users.noreply.github.com>
Section: games
Priority: optional
Installed-Size: {installed_size}
Depends: libc6, libgcc-s1, libstdc++6, libx11-6, libxcursor1, libxinerama1, libxrandr2, libxi6, libxrender1, libasound2t64 | libasound2, libpulse0, libgl1, libvulkan1, libwayland-client0, libwayland-cursor0, libwayland-egl1, libxkbcommon0
Recommends: libgl1-mesa-dri, mesa-vulkan-drivers, libegl1
Homepage: https://github.com/nu4ddi4/office-chair-game
Description: Office chair physics comedy (김 대리, 나 좀 밀어봐)
 A physics ragdoll employee pushes the boss across the office on a wheeled chair
 without spilling his coffee. Single player, keyboard and mouse.
"""


def build_deb(binary, licenses, destination, version):
    if shutil.which('dpkg-deb') is None:
        raise RuntimeError('dpkg-deb is required for --deb')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected the game semantic version')
    package = destination / f'{NAME}_{version}_amd64.deb'
    with tempfile.TemporaryDirectory() as temp:
        staging = Path(temp) / 'package'
        staging.mkdir(mode=0o755)
        control = staging / 'DEBIAN'
        control.mkdir()
        files = [(binary, f'opt/{NAME}/{BINARY}', 0o755),
                 (licenses, f'usr/share/doc/{NAME}/copyright', 0o644),
                 (PACKAGING / (NAME+'.desktop'), f'usr/share/applications/{NAME}.desktop', 0o644),
                 (PACKAGING / (NAME+'.png'), f'usr/share/icons/hicolor/256x256/apps/{NAME}.png', 0o644)]
        for source, relative, mode in files:
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            target.chmod(mode)
        # One copy of the full notices, also available beside the executable.
        (staging / f'opt/{NAME}/LICENSES.txt').symlink_to(f'/usr/share/doc/{NAME}/copyright')
        launcher = staging / f'usr/bin/{NAME}'
        launcher.parent.mkdir(parents=True)
        launcher.write_text(f'#!/bin/sh\nexec /opt/{NAME}/{BINARY} "$@"\n', encoding='utf-8')
        launcher.chmod(0o755)
        size = sum(p.stat().st_size for p in staging.rglob('*') if not p.is_symlink() and p.is_file())
        metadata = control / 'control'
        metadata.write_text(CONTROL.format(name=NAME, version=version, installed_size=(size+1023)//1024), encoding='utf-8')
        metadata.chmod(0o644)
        for directory in [staging, *staging.rglob('*')]:
            if not directory.is_symlink() and directory.is_dir():
                directory.chmod(0o755)
        # dpkg-deb packages the bytes directly; do not strip the embedded Godot PCK.
        run(['dpkg-deb', '--root-owner-group', '--build', str(staging), str(package)])
    return package


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
    parser.add_argument('--deb', action='store_true')
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
    if args.deb:
        outputs.append(build_deb(binary, licenses, DIST, version))
    outputs.append(licenses)
    (DIST/'SHA256SUMS-linux.txt').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in outputs), encoding='utf-8')
    # The bare executable is already inside both packages; do not ship a third copy.
    binary.unlink()
    print('Linux build:', ', '.join(p.name for p in outputs), 'version', version)


if __name__ == '__main__':
    main()
