# Ctx

Ctx links downloaded files to their origin webpage (title + URL) plus an optional note, so you can later look up where a file came from.

## What this project includes
- `app-swift/`: macOS menu bar app (`Ctx.app`)
- `cli/`: `ctx` command-line wrapper for daily use
- `core-python/`: `ctx-core` engine (JSON command interface)
- `tests/`: Python core tests
- `scripts/`: build, packaging, and smoke-test helpers
- `docs/`: JSON contract, permissions, release process

## Requirements
- macOS (Safari integration is part of MVP)
- Python 3
- Swift toolchain (only needed to run/build the app from source)

Ctx may request macOS Automation permission to read Safari tab title/URL during capture.

## From clone to first run

### Option A: Run the CLI (fastest)
1. Clone and enter the repo:
```bash
git clone <your-repo-url>
cd download-context
```
2. (Optional) use a separate local DB for development:
```bash
export CTX_DB_PATH=/tmp/ctx-dev.sqlite
```
3. Run a command to confirm the tool works:
```bash
./cli/ctx search ""
```
4. Capture a recent download from Safari:
```bash
./cli/ctx capture
```
5. Look up a file later:
```bash
./cli/ctx lookup /absolute/path/to/file
```

### Option B: Run the macOS menu bar app
1. Clone and enter the repo:
```bash
git clone <your-repo-url>
cd download-context
```
2. Start the app:
```bash
swift run --package-path app-swift Ctx
```
3. Use the menu bar icon to run Capture / Lookup / Search.
4. On first capture, allow macOS Automation access for Safari if prompted.

### Option C: Build distributable artifacts, then run
1. Clone and enter the repo:
```bash
git clone <your-repo-url>
cd download-context
```
2. Build packages:
```bash
./scripts/package_app.sh
```
3. Use generated outputs in `dist/`:
- `Ctx.app.zip` for the app
- `ctx-cli.zip` for the CLI

## Quick start paths

### Path 1: Use prebuilt release artifacts
1. Build/package artifacts:
```bash
./scripts/package_app.sh
```
2. Use outputs in `dist/`:
- `Ctx.app.zip` (menu bar app)
- `ctx-cli.zip` (CLI bundle)
- `ctx-core` (core executable)
- `SHA256SUMS.txt` (checksums)

### Path 2: Run the menu bar app from source
```bash
swift run --package-path app-swift Ctx
```

### Path 3: Use the CLI from source
```bash
export CTX_DB_PATH=/tmp/ctx-dev.sqlite  # optional override
./cli/ctx capture
./cli/ctx lookup /absolute/path/to/file.pdf
./cli/ctx search "invoice"
./cli/ctx open <capture-id>
./cli/ctx reveal /absolute/path/to/file.pdf
./cli/ctx reveal-id <capture-id>
```

### Path 4: Call the core engine directly (JSON output)
```bash
python3 -m ctx_core search --q "" --limit 20
```
Run from repo root with `PYTHONPATH` including `core-python` if needed.

## Common workflows
- Capture latest download: `ctx capture`
- Find origin for a local file: `ctx lookup <file_path>`
- Search saved records: `ctx search <query>`
- Open source page for a capture: `ctx open <capture-id>`

## Database location
App and CLI share the same SQLite database path resolution:
1. `CTX_DB_PATH` (if set)
2. `~/Library/Application Support/Ctx/ctx.sqlite`

## Development and verification
Run smoke tests:
```bash
./scripts/run_smoke_tests.sh
```

Run Python unit tests:
```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Documentation
- JSON command contract: `docs/json-contract.md`
- Product/spec details: `docs/spec.md`
- Permissions: `docs/permissions.md`
- Release process: `docs/release.md`
