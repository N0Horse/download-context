from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import time
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
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

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
        time.sleep(2.2)
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

    def test_lookup_after_rename_and_move_updates_metadata(self) -> None:
        time.sleep(2.2)
        rc, payload = self.run_core(
            "capture",
            "--downloads-dir",
            str(self.tmp_dir),
            "--within",
            "60",
            "--origin-title",
            "Rename Test",
            "--origin-url",
            "https://example.com/rename",
            "--source-app",
            "test",
        )
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])

        moved_dir = self.tmp_dir / "subdir"
        moved_dir.mkdir()
        moved_path = moved_dir / "renamed.txt"
        self.sample.rename(moved_path)

        rc, payload = self.run_core("lookup", "--path", str(moved_path))
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["data"]["count"], 1)
        self.assertEqual(payload["data"]["records"][0]["file_name"], "renamed.txt")
        self.assertEqual(payload["data"]["records"][0]["file_path_at_capture"], str(moved_path.resolve()))

        rc, payload = self.run_core("search", "--q", "renamed.txt")
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertGreaterEqual(payload["data"]["count"], 1)

        rc, payload = self.run_core("search", "--q", "subdir")
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertGreaterEqual(payload["data"]["count"], 1)

    def test_search_can_reconcile_without_prior_lookup(self) -> None:
        time.sleep(2.2)
        rc, payload = self.run_core(
            "capture",
            "--downloads-dir",
            str(self.tmp_dir),
            "--within",
            "60",
            "--origin-title",
            "Search Reconcile",
            "--origin-url",
            "https://example.com/reconcile",
            "--source-app",
            "test",
        )
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])

        moved_dir = self.tmp_dir / "moved"
        moved_dir.mkdir()
        moved_path = moved_dir / "renamed-via-search.txt"
        self.sample.rename(moved_path)

        rc, payload = self.run_core(
            "search",
            "--q",
            "reconcile",
            "--scan-root",
            str(self.tmp_dir),
        )
        self.assertEqual(rc, 0)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["data"]["count"], 1)
        self.assertGreaterEqual(payload["data"].get("reconciled", 0), 1)
        self.assertEqual(payload["data"]["results"][0]["file_name"], "renamed-via-search.txt")
        self.assertEqual(
            payload["data"]["results"][0]["file_path_at_capture"],
            str(moved_path.resolve()),
        )


if __name__ == "__main__":
    unittest.main()
