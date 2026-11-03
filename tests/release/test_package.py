import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('prepare_release', ROOT / 'scripts/prepare-release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'verified'
        self.source.mkdir()
        for name in release.FILES:
            (self.source / name).write_bytes(b'MZverified executable' if name.endswith('.exe') else b'license')
        self.update_checksum()

    def update_checksum(self):
        (self.source / 'SHA256SUMS.txt').write_text(''.join(release.digest(self.source/name)+'  '+name+'\n' for name in release.FILES))

    def prepare(self, tag='OfficeChairChaos-v0.1.0'):
        return release.prepare(self.source, self.root / 'publish', '0.1.0', tag, '123', 'a' * 40, 'example/renamed-office')

    def test_verified_binary_is_preserved_and_bundled_with_licenses(self):
        archive = self.prepare()
        assets = archive.parent
        self.assertEqual((assets / 'OfficeChairChaos-Setup.exe').read_bytes(), (self.source / 'OfficeChairChaos-Setup.exe').read_bytes())
        self.assertEqual({p.name for p in assets.iterdir()}, {'OfficeChairChaos-Setup.exe', 'OfficeChairChaos-0.1.0-Windows-x64.zip', 'SHA256SUMS.txt'})
        with zipfile.ZipFile(archive) as bundle:
            self.assertEqual(bundle.read('OfficeChairChaos/OfficeChairChaos.exe'), (self.source / 'OfficeChairChaos.exe').read_bytes())
            self.assertIn('OfficeChairChaos/LICENSES.txt', bundle.namelist())
            self.assertNotIn('OfficeChairChaos/office-chair.install.json', bundle.namelist())
        self.assertIn('https://github.com/example/renamed-office/actions/runs/123', (assets.parent / 'notes.md').read_text(encoding='utf-8'))
        for line in (assets / 'SHA256SUMS.txt').read_text().splitlines():
            expected, name = line.split()
            self.assertEqual(hashlib.sha256((assets / name).read_bytes()).hexdigest(), expected)

    def test_corrupt_artifact_is_rejected_before_packaging(self):
        (self.source / 'OfficeChairChaos.exe').write_bytes(b'MZchanged')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.prepare()
        self.assertFalse((self.root / 'publish').exists())

    def test_corrupt_installer_is_rejected(self):
        (self.source / 'OfficeChairChaos-Setup.exe').write_bytes(b'MZchanged')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.prepare()

    def test_missing_license_is_rejected(self):
        (self.source / 'LICENSES.txt').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            self.prepare()

    def test_other_product_or_version_tag_is_rejected(self):
        for tag in ['SecurityLab-0.1.0', 'OfficeChairChaos-v0.2.0']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                self.prepare(tag)

    def test_non_windows_binary_is_rejected_even_with_matching_checksum(self):
        (self.source / 'OfficeChairChaos.exe').write_bytes(b'\x7fELF')
        self.update_checksum()
        with self.assertRaisesRegex(ValueError, 'Windows'):
            self.prepare()


if __name__ == '__main__':
    unittest.main()
