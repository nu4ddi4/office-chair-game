#!/usr/bin/env python3
"""Remove duplicate loose assets only after proving the old portable ZIP is intact."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

REDUNDANT = ('OfficeChairChaos.exe', 'CREDITS.txt', 'FONT-LICENSE.txt', 'LICENSES.txt')

def checksums(text):
    return {parts[1].lstrip('*'):parts[0] for line in text.splitlines() if len(parts := line.split()) == 2}

def verify_archive(path, manifest):
    expected = checksums(manifest).get(path.name)
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if not expected or actual != expected:
        raise ValueError('The retained portable archive checksum does not match')
    with zipfile.ZipFile(path) as archive:
        prefix = 'OfficeChairChaos/'
        for name in REDUNDANT:
            item = archive.getinfo(prefix+name)
            if not 0 < item.file_size < 512*1024*1024:
                raise ValueError('The archive is missing a required binary or license')
        if 'CMHT Oculus' not in archive.read(prefix+'CREDITS.txt').decode('utf-8'):
            raise ValueError('The archive is missing chair attribution')
        if 'SIL OPEN FONT LICENSE' not in archive.read(prefix+'FONT-LICENSE.txt').decode('utf-8'):
            raise ValueError('The archive is missing the font license')
        inner = checksums(archive.read(prefix+'SHA256SUMS.txt').decode('utf-8'))
        with archive.open(prefix+'OfficeChairChaos.exe') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != inner.get('OfficeChairChaos.exe'):
                raise ValueError('The archived executable checksum does not match')
    return actual

def run(*args):
    return subprocess.check_output(['gh', *args], text=True, encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'OfficeChairChaos-v\d+\.\d+\.\d+', args.tag):
        raise ValueError('Only Office Chair Chaos releases can be consolidated')
    info = json.loads(run('release', 'view', args.tag, '--json', 'assets,isDraft'))
    if info['isDraft']: raise ValueError('Expected a published archived release')
    names = {asset['name'] for asset in info['assets']}
    duplicates = [name for name in REDUNDANT if name in names]
    if not duplicates:
        print('No duplicate loose assets:', args.tag); return
    archive_name = 'OfficeChairChaos-'+args.tag.removeprefix('OfficeChairChaos-v')+'-Windows-x64.zip'
    if archive_name not in names or 'SHA256SUMS.txt' not in names:
        raise ValueError('The retained portable ZIP and checksum are required')
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        run('release', 'download', args.tag, '--pattern', archive_name, '--pattern', 'SHA256SUMS.txt', '--dir', str(folder))
        digest = verify_archive(folder/archive_name, (folder/'SHA256SUMS.txt').read_text(encoding='utf-8'))
        print('Verified retained ZIP and all original license notices:', args.tag)
        if args.apply:
            (folder/'SHA256SUMS.txt').write_text(digest+'  '+archive_name+'\n', encoding='utf-8')
            run('release', 'upload', args.tag, str(folder/'SHA256SUMS.txt'), '--clobber')
            for name in duplicates:
                run('release', 'delete-asset', args.tag, name, '--yes')
                print('Removed duplicate:', name)
        else:
            print('Would remove:', ', '.join(duplicates))

if __name__ == '__main__': main()
