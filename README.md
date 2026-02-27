# Ctx

Ctx is a macOS menu bar app that links downloaded files to their source webpage (title + URL) with an optional note.

## Requirements
- macOS
- Python 3
- Swift toolchain

## Quick Start
1. Clone the repository:
```bash
git clone https://github.com/N0Horse/download-context
cd download-context
```

2. Build the app bundle:
```bash
./scripts/build_app.sh
```

3. Run the built app:
```bash
open dist/Ctx.app
```

4. Use the menu bar icon to capture and look up download context.

5. On first capture, allow macOS Automation permission for Safari when prompted.

## CLI Reference
Run from repo root:
```bash
./cli/ctx <command> [options]
```

### `capture`
Capture the latest recent download and link it to the active Safari tab.
```bash
./cli/ctx capture [--downloads-dir <path>] [--within <seconds>] [--note "<text>"] [--no-note] [--json]
```
- `--downloads-dir`: downloads folder to scan (default: `~/Downloads`)
- `--within`: time window in seconds (default: `60`)
- `--note`: optional note text
- `--no-note`: skip interactive note prompt
- `--json`: print raw JSON response

### `lookup`
Look up saved context by file path.
```bash
./cli/ctx lookup <file_path> [--json]
```
- `--json`: print raw JSON response

### `search`
Search saved capture records.
```bash
./cli/ctx search <query> [--limit <n>] [--json]
```
- `--limit`: max results (default: `20`)
- `--json`: print raw JSON response

### `open`
Open the source URL for a capture ID.
```bash
./cli/ctx open <capture_id>
```

### `reveal`
Reveal a local file in Finder.
```bash
./cli/ctx reveal <file_path>
```

### `reveal-id`
Reveal the captured file path for a capture ID in Finder.
```bash
./cli/ctx reveal-id <capture_id>
```

## Notes
- The built app is located at `dist/Ctx.app`.
- Default database path: `~/Library/Application Support/Ctx/ctx.sqlite`.
- You can override DB location with `CTX_DB_PATH`.
