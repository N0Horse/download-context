from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class CtxCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(__file__).resolve().parent.parent
        self.env = os.environ.copy()
        self.env["PYTHONPATH"] = str(self.repo / "core-python")
        self.tmp_db = tempfile.NamedTemporaryFile(prefix="ctx-test-", suffix=".sqlite", delete=False)
        self.tmp_db.close()
        self.env["CTX_DB_PATH"] = self.tmp_db.name

        self.tmp_dir = Path(tempfile.mkdtemp(prefix="ctx-test-dl-"))
        self.sample = self.tmp_dir / "sample.txt"
        self.sample.write_text("hello", encoding="utf-8")

    def tearDown(self) -> None:
        Path(self.tmp_db.name).unlink(missing_ok=True)
        for child in self.tmp_dir.glob("*"):
            child.unlink(missing_ok=True)
        self.tmp_dir.rmdir()

    def run_core(self, *args: str) -> tuple[int, dict]:
        proc = subprocess.run(
            ["python3", "-m", "ctx_core", *args],
            capture_output=True,
            text=True,
            cwd=self.repo,
            env=self.env,
            check=False,
        )
        payload = json.loads(proc.stdout)
        return proc.returncode, payload

    def test_capture_lookup_search(self) -> None:
        rc, payload = self.run_core(
            "capture",
            "--downloads-dir",
            str(self.tmp_dir),
            "--within",
            "60",
            "--origin-title",
            "Example",
            "--origin-url",
            "https://example.com",
            "--source-app",
            "test",
        )
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])

        rc, payload = self.run_core("lookup", "--path", str(self.sample))
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["data"]["count"], 1)

        rc, payload = self.run_core("search", "--q", "example")
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertGreaterEqual(payload["data"]["count"], 1)


if __name__ == "__main__":
    unittest.main()
