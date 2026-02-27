from __future__ import annotations

import os
from pathlib import Path


DEFAULT_DB_PATH = Path("~/Library/Application Support/Ctx/ctx.sqlite").expanduser()


def resolve_db_path() -> Path:
    env_path = os.environ.get("CTX_DB_PATH", "").strip()
    if env_path:
        return Path(env_path).expanduser().resolve()
    return DEFAULT_DB_PATH


def ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
