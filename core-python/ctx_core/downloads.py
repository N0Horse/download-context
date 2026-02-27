from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

TEMP_SUFFIXES = {
    ".download",
    ".part",
    ".crdownload",
    ".tmp",
    ".partial",
}


@dataclass
class CandidateResult:
    path: Path | None
    had_candidates: bool


def _is_temp_file(path: Path) -> bool:
    lower_name = path.name.lower()
    if lower_name.startswith("."):
        return True
    return any(lower_name.endswith(suffix) for suffix in TEMP_SUFFIXES)


def _is_stable(path: Path, checks: int = 2, sleep_seconds: float = 0.35) -> bool:
    try:
        previous = path.stat()
    except OSError:
        return False

    for _ in range(checks):
        time.sleep(sleep_seconds)
        try:
            current = path.stat()
        except OSError:
            return False
        if current.st_size != previous.st_size or current.st_mtime_ns != previous.st_mtime_ns:
            return False
        previous = current
    return True


def find_newest_stable_download(downloads_dir: Path, within_seconds: int) -> CandidateResult:
    now = time.time()
    cutoff = now - within_seconds
    candidates: list[Path] = []

    if not downloads_dir.exists() or not downloads_dir.is_dir():
        return CandidateResult(path=None, had_candidates=False)

    for path in downloads_dir.iterdir():
        if not path.is_file():
            continue
        if _is_temp_file(path):
            continue
        try:
            stat = path.stat()
        except OSError:
            continue
        if stat.st_mtime < cutoff:
            continue
        candidates.append(path)

    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)

    if not candidates:
        return CandidateResult(path=None, had_candidates=False)

    for path in candidates:
        if _is_stable(path):
            return CandidateResult(path=path, had_candidates=True)

    return CandidateResult(path=None, had_candidates=True)
