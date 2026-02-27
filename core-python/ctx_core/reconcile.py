from __future__ import annotations

import os
import time
from pathlib import Path

from ctx_core.hashing import sha256_file

DEFAULT_SCAN_ROOTS = [
    "~/Downloads",
    "~/Desktop",
    "~/Documents",
    "~",
]

SKIP_DIR_NAMES = {
    ".git",
    ".Trash",
    "Library",
    "node_modules",
    "venv",
    ".venv",
}


def resolve_scan_roots(cli_roots: list[str] | None = None) -> list[Path]:
    roots: list[str] = []

    if cli_roots:
        roots.extend(cli_roots)
    else:
        env_roots = os.environ.get("CTX_SCAN_ROOTS", "").strip()
        if env_roots:
            roots.extend([x.strip() for x in env_roots.split(",") if x.strip()])
        else:
            roots.extend(DEFAULT_SCAN_ROOTS)

    uniq: list[Path] = []
    seen: set[str] = set()
    for raw in roots:
        path = Path(raw).expanduser()
        try:
            resolved = path.resolve()
        except OSError:
            continue
        if not resolved.exists() or not resolved.is_dir():
            continue
        key = str(resolved)
        if key in seen:
            continue
        seen.add(key)
        uniq.append(resolved)
    return uniq


def find_file_by_hash(
    *,
    file_hash: str,
    file_size_bytes: int,
    scan_roots: list[Path],
    max_seconds: float = 3.0,
    max_candidates: int = 2000,
) -> Path | None:
    if file_size_bytes < 0:
        return None

    deadline = time.monotonic() + max_seconds
    hashed_candidates = 0

    for root in scan_roots:
        for dirpath, dirnames, filenames in os.walk(root):
            if time.monotonic() > deadline:
                return None

            dirnames[:] = [
                d for d in dirnames if d not in SKIP_DIR_NAMES and not d.startswith(".")
            ]

            for filename in filenames:
                if time.monotonic() > deadline or hashed_candidates >= max_candidates:
                    return None

                candidate = Path(dirpath) / filename
                try:
                    stat = candidate.stat()
                except OSError:
                    continue

                if not candidate.is_file():
                    continue
                if stat.st_size != file_size_bytes:
                    continue

                hashed_candidates += 1
                try:
                    candidate_hash = sha256_file(candidate)
                except OSError:
                    continue

                if candidate_hash == file_hash:
                    try:
                        return candidate.resolve()
                    except OSError:
                        return candidate

    return None
