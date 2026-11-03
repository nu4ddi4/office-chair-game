#!/usr/bin/env python3
"""Build the Windows game, consolidated notices and optional per-user installer."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import platform
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def run(command):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', timeout=600)
    print(result.stdout, end='')
    if result.returncode or re.search(r'(SCRIPT ERROR|Parse Error|^ERROR:)', result.stdout, re.M):
        raise RuntimeError('Build or executable verification failed')
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--installer', action='store_true')
    parser.add_argument('--iscc', default=os.environ.get('CHAOS_ISCC', ''))
    args = parser.parse_args()
    if not run([args.godot, '--version']).strip().startswith('4.7.2.stable'):
        raise RuntimeError('Use Godot 4.7.2 stable')
    destination = ROOT / 'chaos-dist'
    destination.mkdir(exist_ok=True)
    run([args.godot, '--headless', '--path', 'godot', '--export-release', 'Windows Desktop'])
    sections = [('Asset credits', ROOT/'godot/assets/credits.txt'),
                ('Engine and bundled components', ROOT/'godot/LICENSES.txt'),
                ('Noto Sans KR font', ROOT/'godot/assets/fonts/OFL.txt')]
    (destination/'LICENSES.txt').write_text('\n\n'.join(
        title+'\n'+'='*len(title)+'\n'+path.read_text(encoding='utf-8') for title,path in sections), encoding='utf-8')
    for obsolete in ['CREDITS.txt', 'FONT-LICENSE.txt']:
        (destination/obsolete).unlink(missing_ok=True)
    exe = destination/'OfficeChairChaos.exe'
    assert exe.read_bytes()[:2] == b'MZ', 'Expected a Windows executable'
    version = re.search(r'^config/version="([^"]+)"', (ROOT/'godot/project.godot').read_text(), re.M).group(1)
    (destination/'office-chair.install.json').write_text(json.dumps(
        {'product':'OfficeChairChaos','app_id':'OfficeChairChaos','version':version}), encoding='utf-8')
    if args.verify:
        if platform.system() != 'Windows': raise RuntimeError('--verify requires a Windows host')
        console = destination/'OfficeChairChaos.console.exe'
        raw = run([str(console if console.exists() else exe), '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '120',
                   '--', '--chaos-test', '--mission', '1', '--package-smoke'])
        if 'CHAOS_PACKAGE_SMOKE {"passed":true}' not in raw:
            raise RuntimeError('Exported game did not pass its runtime check')
    outputs = [exe, destination/'LICENSES.txt']
    if args.installer:
        if platform.system() != 'Windows' or not args.iscc: raise RuntimeError('A Windows Inno Setup compiler is required')
        run([args.iscc, '/DGameVersion='+version, '/DBuildDir='+str(destination), str(ROOT/'installer/OfficeChairChaos.iss')])
        outputs.append(destination/'OfficeChairChaos-Setup.exe')
    (destination/'SHA256SUMS.txt').write_text(''.join(
        hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name+'\n' for path in outputs), encoding='utf-8')
    print('Windows build:', exe, 'version', version)

if __name__ == '__main__': main()
