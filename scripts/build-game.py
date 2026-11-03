#!/usr/bin/env python3
"""Export a portable Windows game. Never publishes or updates the legacy product."""
import argparse
import hashlib
from pathlib import Path
import platform
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def run(command):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding='utf-8', timeout=420)
    print(result.stdout, end='')
    if result.returncode or re.search(r'(SCRIPT ERROR|Parse Error|^ERROR:)', result.stdout, re.M):
        raise RuntimeError('Build or executable verification failed')
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--verify', action='store_true', help='Run the exported executable on Windows')
    args = parser.parse_args()
    if not run([args.godot, '--version']).strip().startswith('4.7.2.stable'):
        raise RuntimeError('Use Godot 4.7.2 stable')
    destination = ROOT / 'chaos-dist'
    destination.mkdir(exist_ok=True)
    run([args.godot, '--headless', '--path', 'godot', '--export-release', 'Windows Desktop'])
    for source, name in [(ROOT/'godot/assets/credits.txt', 'CREDITS.txt'),
                         (ROOT/'godot/LICENSES.txt', 'LICENSES.txt'),
                         (ROOT/'godot/assets/fonts/OFL.txt', 'FONT-LICENSE.txt')]:
        shutil.copyfile(source, destination/name)
    exe = destination/'OfficeChairChaos.exe'
    assert exe.read_bytes()[:2] == b'MZ', 'Expected a Windows executable'
    (destination/'SHA256SUMS.txt').write_text(
        hashlib.sha256(exe.read_bytes()).hexdigest()+'  '+exe.name+'\n', encoding='utf-8')
    if args.verify:
        if platform.system() != 'Windows':
            raise RuntimeError('--verify requires a Windows host')
        console = destination/'OfficeChairChaos.console.exe'
        raw = run([str(console if console.exists() else exe), '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '120',
                   '--', '--chaos-test', '--mission', '1', '--package-smoke'])
        if 'CHAOS_PACKAGE_SMOKE {"passed":true}' not in raw:
            raise RuntimeError('Exported game did not pass its runtime check')
    print('Windows portable build:', exe)

if __name__ == '__main__':
    main()
