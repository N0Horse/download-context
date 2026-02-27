# Ctx

Ctx links local files to their origin webpages (title + URL) with optional notes.

## Repo layout
- `core-python/`: `ctx-core` engine (JSON CLI)
- `cli/`: `ctx` user CLI wrapper
- `app-swift/`: Swift menu bar app scaffold
- `docs/`: contract, permissions, release docs
- `scripts/`: build/smoke helpers

## Quickstart (developer)

### 1) Run core from source
```bash
PYTHONPATH=core-python python3 -m ctx_core search --q ""
```

### 2) Run user CLI
```bash
./cli/ctx search ""
```

### 3) Use custom DB path for local tests
```bash
export CTX_DB_PATH=/tmp/ctx.sqlite
```

## Current status
- Python core and CLI implemented.
- Swift app layer scaffolded (menu bar structure + core bridge code skeleton).
