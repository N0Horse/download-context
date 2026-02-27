from __future__ import annotations

import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any

from ctx_core.paths import ensure_parent_dir, resolve_db_path


class Database:
    def __init__(self, db_path: Path | None = None) -> None:
        self.db_path = db_path or resolve_db_path()
        ensure_parent_dir(self.db_path)
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row

    def close(self) -> None:
        self.conn.close()

    def configure(self) -> None:
        self.conn.execute("PRAGMA journal_mode=WAL;")
        self.conn.execute("PRAGMA foreign_keys=ON;")

    def run_migrations(self) -> None:
        migrations_dir = Path(__file__).resolve().parent.parent / "migrations"
        self.conn.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
              version INTEGER PRIMARY KEY,
              applied_at INTEGER NOT NULL
            )
            """
        )
        applied_versions = {
            row["version"]
            for row in self.conn.execute("SELECT version FROM schema_migrations").fetchall()
        }

        migration_files = sorted(migrations_dir.glob("*.sql"))
        for migration_file in migration_files:
            version = int(migration_file.name.split("_", 1)[0])
            if version in applied_versions:
                continue
            sql = migration_file.read_text(encoding="utf-8")
            with self.conn:
                self.conn.executescript(sql)
                self.conn.execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES (?, ?)",
                    (version, int(time.time())),
                )

    def ensure_fts(self) -> bool:
        expected_columns = {
            "id",
            "file_name",
            "file_path_at_capture",
            "origin_title",
            "origin_url",
            "note",
        }

        try:
            existing_columns = {
                row["name"]
                for row in self.conn.execute("PRAGMA table_info(captures_fts)").fetchall()
            }
            if existing_columns and existing_columns != expected_columns:
                with self.conn:
                    self.conn.execute("DROP TABLE IF EXISTS captures_fts")

            with self.conn:
                self.conn.execute(
                    """
                    CREATE VIRTUAL TABLE IF NOT EXISTS captures_fts USING fts5(
                      id UNINDEXED,
                      file_name,
                      file_path_at_capture,
                      origin_title,
                      origin_url,
                      note
                    )
                    """
                )
                self.conn.execute("DELETE FROM captures_fts")
                self.conn.execute(
                    """
                    INSERT INTO captures_fts (
                      id, file_name, file_path_at_capture, origin_title, origin_url, note
                    )
                    SELECT
                      id,
                      file_name,
                      file_path_at_capture,
                      origin_title,
                      origin_url,
                      coalesce(note, '')
                    FROM captures
                    """
                )
            return True
        except sqlite3.OperationalError:
            return False

    def sync_fts_insert(self, record: dict[str, Any]) -> None:
        try:
            with self.conn:
                self.conn.execute(
                    """
                    INSERT INTO captures_fts (
                      id, file_name, file_path_at_capture, origin_title, origin_url, note
                    )
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        record["id"],
                        record["file_name"],
                        record["file_path_at_capture"],
                        record["origin_title"],
                        record["origin_url"],
                        record.get("note") or "",
                    ),
                )
        except sqlite3.OperationalError:
            pass

    def insert_capture(
        self,
        *,
        file_hash: str,
        file_name: str,
        file_size_bytes: int,
        file_path_at_capture: str,
        origin_title: str,
        origin_url: str,
        note: str | None,
        browser: str = "safari",
        source_app: str | None = None,
        mime_type: str | None = None,
    ) -> dict[str, Any]:
        record = {
            "id": str(uuid.uuid4()),
            "created_at": int(time.time()),
            "file_hash": file_hash,
            "file_name": file_name,
            "file_size_bytes": file_size_bytes,
            "file_path_at_capture": file_path_at_capture,
            "origin_title": origin_title,
            "origin_url": origin_url,
            "note": note,
            "browser": browser,
            "source_app": source_app,
            "mime_type": mime_type,
        }
        with self.conn:
            self.conn.execute(
                """
                INSERT INTO captures (
                  id, created_at, file_hash, file_name, file_size_bytes,
                  file_path_at_capture, origin_title, origin_url, note,
                  browser, source_app, mime_type
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["id"],
                    record["created_at"],
                    record["file_hash"],
                    record["file_name"],
                    record["file_size_bytes"],
                    record["file_path_at_capture"],
                    record["origin_title"],
                    record["origin_url"],
                    record["note"],
                    record["browser"],
                    record["source_app"],
                    record["mime_type"],
                ),
            )

        self.sync_fts_insert(record)
        return record

    def lookup_by_hash(self, file_hash: str, limit: int = 20) -> list[dict[str, Any]]:
        rows = self.conn.execute(
            """
            SELECT * FROM captures
            WHERE file_hash = ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (file_hash, limit),
        ).fetchall()
        return [dict(row) for row in rows]

    def refresh_observed_file_location(self, file_hash: str, observed_path: str) -> None:
        observed_name = Path(observed_path).name
        with self.conn:
            self.conn.execute(
                """
                UPDATE captures
                SET file_name = ?, file_path_at_capture = ?
                WHERE file_hash = ?
                """,
                (observed_name, observed_path, file_hash),
            )
        try:
            with self.conn:
                self.conn.execute(
                    """
                    UPDATE captures_fts
                    SET file_name = ?, file_path_at_capture = ?
                    WHERE id IN (
                      SELECT id FROM captures WHERE file_hash = ?
                    )
                    """,
                    (observed_name, observed_path, file_hash),
                )
        except sqlite3.OperationalError:
            pass

    def search_captures(self, query: str, limit: int = 20) -> tuple[list[dict[str, Any]], str]:
        if query.strip() == "":
            rows = self.conn.execute(
                "SELECT * FROM captures ORDER BY created_at DESC LIMIT ?", (limit,)
            ).fetchall()
            return [dict(row) for row in rows], "recent"

        try:
            rows = self.conn.execute(
                """
                SELECT c.* FROM captures_fts f
                JOIN captures c ON c.id = f.id
                WHERE captures_fts MATCH ?
                ORDER BY c.created_at DESC
                LIMIT ?
                """,
                (query, limit),
            ).fetchall()
            if rows:
                return [dict(row) for row in rows], "fts5"
        except sqlite3.OperationalError:
            pass

        like_q = f"%{query.lower()}%"
        rows = self.conn.execute(
            """
            SELECT * FROM captures
            WHERE lower(file_name) LIKE ?
               OR lower(file_path_at_capture) LIKE ?
               OR lower(origin_title) LIKE ?
               OR lower(origin_url) LIKE ?
               OR lower(coalesce(note, '')) LIKE ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (like_q, like_q, like_q, like_q, like_q, limit),
        ).fetchall()
        return [dict(row) for row in rows], "like"

    def get_capture_by_id(self, capture_id: str) -> dict[str, Any] | None:
        row = self.conn.execute(
            "SELECT * FROM captures WHERE id = ? LIMIT 1", (capture_id,)
        ).fetchone()
        return dict(row) if row else None
