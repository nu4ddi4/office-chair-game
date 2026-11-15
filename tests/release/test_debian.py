import hashlib
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


linux = module('build_linux', 'scripts/build-linux.py')
release = module('prepare_debian_release', 'scripts/prepare-release.py')


@unittest.skipUnless(shutil.which('dpkg-deb') and Path('/bin/true').exists(), 'Debian packaging tools required')
class DebianTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'windows'
        self.source.mkdir()
        for name in release.FILES:
            (self.source / name).write_bytes(b'MZverified' if name.endswith('.exe') else b'full notices')
        (self.source / 'SHA256SUMS.txt').write_text(''.join(
            release.digest(self.source / name)+'  '+name+'\n' for name in release.FILES), encoding='utf-8')
        self.linux_source = self.root / 'linux'
        self.linux_source.mkdir()
        binary = self.root / linux.BINARY
        self.original = Path('/bin/true').read_bytes()+b'GODOT-PCK-SENTINEL'
        binary.write_bytes(self.original)
        notices = self.root / 'LICENSES.txt'
        notices.write_bytes(b'full asset, engine and font notices')
        self.package = linux.build_deb(binary, notices, self.linux_source, '0.1.2')
        self.manifest()

    def manifest(self):
        (self.linux_source / 'SHA256SUMS-linux.txt').write_text(
            release.digest(self.package)+'  '+self.package.name+'\n', encoding='utf-8')

    def prepare(self):
        return release.prepare(self.source, self.root / 'publish', '0.1.2', 'OfficeChairChaos-v0.1.2',
                               '123', 'a'*40, 'example/office', linux_source=self.linux_source)

    def test_real_deb_preserves_embedded_pack_and_installs_desktop_and_notices(self):
        identity = subprocess.check_output(['dpkg-deb', '--show', '--showformat=${Package}\n${Version}\n${Architecture}\n', str(self.package)], text=True)
        self.assertEqual(identity.splitlines(), ['office-chair-chaos', '0.1.2', 'amd64'])
        raw = subprocess.check_output(['dpkg-deb', '--fsys-tarfile', str(self.package)])
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            members = {m.name.removeprefix('./'):m for m in archive.getmembers()}
            self.assertTrue(all(m.uid == m.gid == 0 for m in members.values()))
            executable = members['opt/office-chair-chaos/'+linux.BINARY]
            self.assertEqual(archive.extractfile(executable).read(), self.original)
            self.assertTrue(executable.mode & 0o111)
            self.assertTrue(members['usr/bin/office-chair-chaos'].mode & 0o111)
            self.assertIn('usr/share/applications/office-chair-chaos.desktop', members)
            self.assertIn('usr/share/icons/hicolor/256x256/apps/office-chair-chaos.png', members)
            self.assertEqual(archive.extractfile(members['usr/share/doc/office-chair-chaos/copyright']).read(), b'full asset, engine and font notices')
            self.assertTrue(members['opt/office-chair-chaos/LICENSES.txt'].issym())

    def test_release_adds_verified_deb_and_shared_checksums(self):
        archive = self.prepare()
        assets = archive.parent
        self.assertEqual({p.name for p in assets.iterdir()}, {
            'OfficeChairChaos-Setup.exe', 'OfficeChairChaos-0.1.2-Windows-x64.zip',
            'office-chair-chaos_0.1.2_amd64.deb', 'SHA256SUMS.txt'})
        self.assertEqual((assets / self.package.name).read_bytes(), self.package.read_bytes())
        self.assertIn('sudo apt install ./'+self.package.name, (assets.parent / 'notes.md').read_text(encoding='utf-8'))
        for line in (assets / 'SHA256SUMS.txt').read_text().splitlines():
            expected, name = line.split()
            self.assertEqual(hashlib.sha256((assets / name).read_bytes()).hexdigest(), expected)

    def test_changed_deb_cannot_be_published(self):
        self.package.write_bytes(self.package.read_bytes()+b'corrupt')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.prepare()
        self.assertFalse((self.root / 'publish').exists())

    def test_matching_hash_cannot_hide_wrong_architecture(self):
        staging = self.root / 'wrong-arch'
        subprocess.run(['dpkg-deb', '--raw-extract', str(self.package), str(staging)], check=True)
        control = staging / 'DEBIAN/control'
        control.write_text(control.read_text(encoding='utf-8').replace('Architecture: amd64', 'Architecture: arm64'), encoding='utf-8')
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(staging), str(self.package)], check=True, stdout=subprocess.PIPE)
        self.manifest()
        with self.assertRaisesRegex(ValueError, 'architecture'):
            self.prepare()
        self.assertFalse((self.root / 'publish').exists())
