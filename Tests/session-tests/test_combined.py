import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('combined', Path(__file__).resolve().parents[2] / 'Scripts/package-combined-session.py')
combined = importlib.util.module_from_spec(spec)
spec.loader.exec_module(combined)

class CombinedTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.preview = Path(self.temp.name) / 'preview.ipa'
        self.output = Path(self.temp.name) / 'combined.ipa'
        self.new_binary = b'\xcf\xfa\xed\xfe' + b'new UI fixture'
        with zipfile.ZipFile(self.preview, 'w') as z:
            z.writestr(combined.BINARY, self.new_binary)
            z.writestr(combined.UI + 'Info.plist', b'new info fixture')
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w') as z:
            for name in combined.REQUIRED:
                z.writestr(name, ('original ' + name).encode())
            z.writestr(combined.ROOT + 'Info.plist', b'original host metadata')
            z.writestr(combined.BINARY, b'old UI')
            z.writestr(combined.UI + 'obsolete', b'obsolete resource')
            z.writestr(combined.ROOT + '_CodeSignature/CodeResources', b'old seal')
        self.template = buf.getvalue()
        self.digest = hashlib.sha256(self.template).hexdigest()

    def test_preserves_runtime_replaces_ui_and_removes_stale_files(self):
        report = combined.combine(self.preview, self.template, self.output, self.digest)
        with zipfile.ZipFile(self.output) as z:
            self.assertEqual(z.read(combined.BINARY), self.new_binary)
            for name in combined.REQUIRED:
                self.assertEqual(z.read(name), ('original ' + name).encode())
            self.assertEqual(z.read(combined.ROOT + 'Info.plist'), b'original host metadata')
            self.assertNotIn(combined.UI + 'obsolete', z.namelist())
            self.assertNotIn(combined.ROOT + '_CodeSignature/CodeResources', z.namelist())
        self.assertFalse(report['device_tested'])
        self.assertTrue(report['requires_resigning'])

    def test_rejects_changed_template(self):
        with self.assertRaisesRegex(ValueError, 'checksum'):
            combined.combine(self.preview, self.template + b'tampered', self.output, self.digest)
        self.assertFalse(self.output.exists())

    def test_rejects_missing_compiled_ui(self):
        with zipfile.ZipFile(self.preview, 'w') as z:
            z.writestr('placeholder', b'not a framework')
        with self.assertRaisesRegex(ValueError, 'Compiled UI'):
            combined.combine(self.preview, self.template, self.output, self.digest)
        self.assertFalse(self.output.exists())

if __name__ == '__main__':
    unittest.main()
