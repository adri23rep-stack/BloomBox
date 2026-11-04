import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('packager', Path(__file__).resolve().parents[2] / 'Scripts/package-session-preview.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)

class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'LiveContainer.app'
        self.app.mkdir()
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'LiveContainer'}))
        self.output = self.root / 'preview.ipa'

    def executable(self):
        binary = self.app / 'LiveContainer'
        binary.write_bytes(b'test fixture, not an iOS binary')
        binary.chmod(0o755)

    def test_missing_executable_rejected(self):
        with self.assertRaisesRegex(ValueError, 'executable'):
            packager.package(self.app, self.output)
        self.assertFalse(self.output.exists())

    def test_missing_multitask_extension_rejected(self):
        self.executable()
        with self.assertRaisesRegex(ValueError, 'LiveProcess'):
            packager.package(self.app, self.output)
        self.assertFalse(self.output.exists())

    def test_payload_and_extension_and_executable_mode_preserved(self):
        self.executable()
        extension = self.app / 'PlugIns/LiveProcess.appex'
        extension.mkdir(parents=True)
        (extension / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'LiveProcess'}))
        packager.package(self.app, self.output)
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertIn('Payload/LiveContainer.app/PlugIns/LiveProcess.appex/Info.plist', archive.namelist())
            mode = archive.getinfo('Payload/LiveContainer.app/LiveContainer').external_attr >> 16
            self.assertEqual(mode & 0o777, 0o755)

if __name__ == '__main__':
    unittest.main()
