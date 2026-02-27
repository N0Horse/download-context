from __future__ import annotations

import argparse
import json
import mimetypes
import sys
from pathlib import Path
from typing import Any

from ctx_core import SCHEMA_VERSION
from ctx_core.db import Database
from ctx_core.downloads import find_newest_stable_download
from ctx_core.errors import CtxError
from ctx_core.hashing import sha256_file
from ctx_core.reconcile import find_file_by_hash, resolve_scan_roots


def ok(data: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "ok": True,
        "data": data,
    }


def fail(code: str, message: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "ok": False,
        "error": {
            "code": code,
            "message": message,
            "details": details or {},
        },
    }


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def require_safari_context(origin_title: str | None, origin_url: str | None) -> tuple[str, str]:
    if not origin_title or not origin_url:
        raise CtxError(
            code="SAFARI_CONTEXT_MISSING",
            message="Safari context is required for capture.",
        )
    return origin_title, origin_url


def cmd_capture(args: argparse.Namespace, db: Database) -> dict[str, Any]:
    origin_title, origin_url = require_safari_context(args.origin_title, args.origin_url)

    downloads_dir = Path(args.downloads_dir).expanduser().resolve()
    result = find_newest_stable_download(downloads_dir, args.within)
    if result.path is None and not result.had_candidates:
        raise CtxError(
            code="NO_RECENT_DOWNLOAD",
            message=f"No file created in Downloads within last {args.within} seconds.",
        )
    if result.path is None and result.had_candidates:
        raise CtxError(
            code="DOWNLOAD_NOT_STABLE",
            message="Download not stable yet.",
        )

    target = result.path
    assert target is not None

    try:
        file_hash = sha256_file(target)
    except OSError as exc:
        raise CtxError(
            code="HASH_ERROR",
            message="Failed to hash file.",
            details={"path": str(target), "reason": str(exc)},
        ) from exc

    guessed_type, _ = mimetypes.guess_type(target.name)
    record = db.insert_capture(
        file_hash=file_hash,
        file_name=target.name,
        file_size_bytes=target.stat().st_size,
        file_path_at_capture=str(target),
        origin_title=origin_title,
        origin_url=origin_url,
        note=args.note,
        browser="safari",
        source_app=args.source_app,
        mime_type=guessed_type,
    )

    return ok(
        {
            "capture": record,
        }
    )


def cmd_lookup(args: argparse.Namespace, db: Database) -> dict[str, Any]:
    path = Path(args.path).expanduser().resolve()
    if not path.exists() or not path.is_file():
        raise CtxError(
            code="FILE_NOT_FOUND",
            message="Lookup file path does not exist or is not a regular file.",
            details={"path": str(path)},
        )

    try:
        file_hash = sha256_file(path)
    except OSError as exc:
        raise CtxError(
            code="HASH_ERROR",
            message="Failed to hash file.",
            details={"path": str(path), "reason": str(exc)},
        ) from exc

    records = db.lookup_by_hash(file_hash, limit=args.limit)
    if records:
        # Keep lookup/search results aligned with the latest observed filename/path
        # when users rename or move the file after capture.
        db.refresh_observed_file_location(file_hash, str(path))
        records = db.lookup_by_hash(file_hash, limit=args.limit)
    return ok(
        {
            "file_hash": file_hash,
            "records": records,
            "count": len(records),
        }
    )


def cmd_search(args: argparse.Namespace, db: Database) -> dict[str, Any]:
    records, backend = db.search_captures(args.q, limit=args.limit)
    reconciled = 0

    if args.reconcile_paths and records:
        scan_roots = resolve_scan_roots(args.scan_root)
        stale = [
            record
            for record in records
            if not Path(record["file_path_at_capture"]).expanduser().exists()
        ]
        hash_to_path: dict[str, str | None] = {}

        for record in stale[: args.reconcile_max_records]:
            file_hash = record["file_hash"]
            observed_path = hash_to_path.get(file_hash)
            if file_hash not in hash_to_path:
                located = find_file_by_hash(
                    file_hash=file_hash,
                    file_size_bytes=record["file_size_bytes"],
                    scan_roots=scan_roots,
                    max_seconds=args.reconcile_max_seconds,
                    max_candidates=args.reconcile_max_candidates,
                )
                observed_path = str(located) if located else None
                hash_to_path[file_hash] = observed_path

            if observed_path and observed_path != record["file_path_at_capture"]:
                db.refresh_observed_file_location(file_hash, observed_path)
                reconciled += 1

        if reconciled > 0:
            records, backend = db.search_captures(args.q, limit=args.limit)

    return ok(
        {
            "query": args.q,
            "backend": backend,
            "results": records,
            "count": len(records),
            "reconciled": reconciled,
        }
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ctx-core")
    sub = parser.add_subparsers(dest="command", required=True)

    p_capture = sub.add_parser("capture")
    p_capture.add_argument("--downloads-dir", default="~/Downloads")
    p_capture.add_argument("--within", type=int, default=60)
    p_capture.add_argument("--origin-title")
    p_capture.add_argument("--origin-url")
    p_capture.add_argument("--note")
    p_capture.add_argument("--source-app")

    p_lookup = sub.add_parser("lookup")
    p_lookup.add_argument("--path", required=True)
    p_lookup.add_argument("--limit", type=int, default=20)

    p_search = sub.add_parser("search")
    p_search.add_argument("--q", required=True)
    p_search.add_argument("--limit", type=int, default=20)
    p_search.add_argument(
        "--reconcile-paths",
        action=argparse.BooleanOptionalAction,
        default=True,
    )
    p_search.add_argument("--scan-root", action="append", default=[])
    p_search.add_argument("--reconcile-max-seconds", type=float, default=8.0)
    p_search.add_argument("--reconcile-max-candidates", type=int, default=2000)
    p_search.add_argument("--reconcile-max-records", type=int, default=10)

    return parser


def run(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    db = Database()
    try:
        db.configure()
        db.run_migrations()
        db.ensure_fts()

        if args.command == "capture":
            payload = cmd_capture(args, db)
        elif args.command == "lookup":
            payload = cmd_lookup(args, db)
        elif args.command == "search":
            payload = cmd_search(args, db)
        else:
            payload = fail("UNKNOWN_COMMAND", f"Unsupported command: {args.command}")
            emit(payload)
            return 2

        emit(payload)
        return 0
    except CtxError as exc:
        emit(fail(exc.code, exc.message, exc.details))
        return 1
    except Exception as exc:  # pragma: no cover - defensive fallback
        emit(fail("DB_ERROR", "Unexpected failure.", {"reason": str(exc)}))
        return 2
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(run(sys.argv[1:]))
