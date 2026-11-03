import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('cleanup',ROOT/'scripts/clean-release-assets.py')
cleanup=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(cleanup)

class CleanupTests(unittest.TestCase):
    def archive(self, folder, omit=''):
        path=Path(folder)/'OfficeChairChaos-0.1.0-Windows-x64.zip'
        files={'OfficeChairChaos.exe':b'MZoriginal','CREDITS.txt':b'CMHT Oculus / CC BY 3.0','LICENSES.txt':b'Godot MIT','FONT-LICENSE.txt':b'SIL OPEN FONT LICENSE'}
        files['SHA256SUMS.txt']=(hashlib.sha256(files['OfficeChairChaos.exe']).hexdigest()+'  OfficeChairChaos.exe\n').encode()
        with zipfile.ZipFile(path,'w') as archive:
            for name,content in files.items():
                if name!=omit:archive.writestr('OfficeChairChaos/'+name,content)
        manifest=hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name+'\n'
        return path,manifest
    def test_licenses_and_executable_are_retained_in_verified_zip(self):
        with tempfile.TemporaryDirectory() as folder:
            path,manifest=self.archive(folder)
            self.assertEqual(cleanup.verify_archive(path,manifest),manifest.split()[0])
    def test_incomplete_archive_cannot_authorize_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            path,manifest=self.archive(folder,'FONT-LICENSE.txt')
            with self.assertRaises(KeyError):cleanup.verify_archive(path,manifest)
    def test_changed_archive_cannot_authorize_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            path,manifest=self.archive(folder)
            path.write_bytes(b'changed')
            with self.assertRaises(ValueError):cleanup.verify_archive(path,manifest)
