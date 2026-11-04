import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

script = Path(__file__).resolve().parents[2] / "Scripts/fetch-bundled-dependencies.py"
spec = importlib.util.spec_from_file_location("upstream", script)
upstream = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upstream)


class RestoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixture = io.BytesIO()
        with zipfile.ZipFile(self.fixture, "w") as archive:
            archive.writestr("Payload/LiveExec32.app/Info.plist", b"plist")
        self.good = self.fixture.getvalue()
        self.relative = "Resources/BundledRuntime/LiveExec32.ipa"
        self.url = "https://github.com/LiveContainer/LiveExec32/releases/download/nightly/test.ipa"
        self.entry = {
            "url": self.url,
            "sha256": hashlib.sha256(self.good).hexdigest(),
            "max_bytes": 8192,
        }

    def source(self, request, timeout):
        self.assertEqual(request.full_url, self.url)
        self.assertEqual(timeout, 120)
        return io.BytesIO(self.good)

    def test_verified_and_cached(self):
        self.assertEqual(upstream.restore(self.root, {self.relative: self.entry}, self.source), [self.relative])
        target = self.root / self.relative
        self.assertEqual(target.read_bytes(), self.good)
        self.assertEqual(upstream.restore(self.root, {self.relative: self.entry},
                         lambda *_args, **_kw: self.fail("redownloaded valid cache")), [])
        self.assertEqual(list(target.parent.glob(".upstream-*")), [])

    def test_checksum_mismatch_never_overwrites(self):
        target = self.root / self.relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"previous")
        bad = dict(self.entry, sha256="0" * 64)
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            upstream.restore(self.root, {self.relative: bad}, self.source)
        self.assertEqual(target.read_bytes(), b"previous")
        self.assertEqual(list(target.parent.glob(".upstream-*")), [])

    def test_refuses_foreign_hosts_and_directory_escape(self):
        with self.assertRaisesRegex(ValueError, "Untrusted"):
            upstream.restore(self.root, {self.relative: dict(self.entry, url="https://example.org/ipa")},
                             self.source)
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            upstream.restore(self.root, {"../secret": self.entry}, self.source)

    def test_download_size_limit(self):
        entry = dict(self.entry, max_bytes=10)
        with self.assertRaisesRegex(ValueError, "size limit"):
            upstream.restore(self.root, {self.relative: entry}, self.source)
        self.assertFalse((self.root / self.relative).exists())


if __name__ == "__main__":
    unittest.main()
