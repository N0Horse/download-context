# Ctx — Download Context Linker (macOS)
**Swift Menu Bar App + Python Core + Optional CLI (Open Source)**

## One-sentence goal
When you download a file, Ctx lets you capture its **origin webpage (title + URL)** plus an optional **note**, so later you can **look up any local file** (even renamed/moved) and instantly see **where/why you got it**.

---

## What users can do (distribution + usage options)

### Option A — Download a prebuilt app (non-technical)
- Go to **GitHub Releases** and download **Ctx.app.zip**.
- Drag **Ctx.app** into **/Applications**.
- Open it → a **menu bar icon** appears.
- Use Capture / Lookup / Search with **no Terminal**.

### Option B — Clone repo and build the app yourself (developers)
- `git clone ...`
- Build the Swift menu bar app (Xcode or `xcodebuild`).
- Build the Python core binary (PyInstaller).
- Run the resulting **Ctx.app** (menu bar).

### Option C — CLI-only (power users / automation)
- Install `ctx` CLI from Releases (or build from repo).
- Use commands:
  - `ctx capture`
  - `ctx lookup <file_path>`
  - `ctx search <query>`
  - `ctx open <id>`
  - `ctx reveal <file_path>`
- This mode can be used without the menu bar app.

> **Shared storage:** App and CLI use the same SQLite database, so users can mix workflows.

---

## Non-negotiable constraints
- Core mapping: **local file ↔ origin webpage (title + URL) + timestamp + note**.
- Lookup must survive rename/move via **SHA-256 file hash**.
- Storage is **local-only** (SQLite in Application Support).
- MVP browser support: **Safari** for origin title+URL (others are out of scope for MVP).
- No browser extension in MVP.

---

## High-level architecture

### Components
1) **Swift Menu Bar App (Ctx.app) — UI wrapper**
- Menu bar UI, dialogs, notifications, optional global hotkey.
- Captures Safari active tab **title + URL** (recommended so Automation permission prompt is attributed to Ctx.app).
- Calls Python core executable and parses JSON.

2) **Python Core (ctx-core) — engine**
- File detection (newest download), hashing, SQLite read/write, search.
- Exposes a stable JSON CLI interface: `capture`, `lookup`, `search`.
- No UI.

3) **CLI (ctx) — optional front-end**
- A small user-facing CLI wrapper that either:
  - calls `ctx-core`, or
  - imports the same Python package (implementation choice).
- Provides the CLI contract described below.

### Communication
- Swift runs `ctx-core` via `Process()` and passes arguments.
- `ctx-core` prints JSON to stdout; Swift parses and displays results.

---

## Core user workflows (MVP)

### Capture Latest Download (primary)
**Intent:** “I just downloaded something; remember where it came from.”

1. User downloads a file in Safari.
2. User triggers capture:
   - Menu bar → **Capture Latest Download…**
   - (Optional) global hotkey (configurable; v1.1 if needed)
3. App detects the newest file in `~/Downloads` created within `N` seconds (default 60).
4. App reads Safari active tab:
   - `origin_title`
   - `origin_url`
5. App shows a Capture dialog:
   - Detected file name (and optional path)
   - Origin page title (clickable) + URL (copy button)
   - Note (optional, single line)
   - Buttons: Save / Cancel
6. On Save, app calls `ctx-core capture` and shows a toast:
   - Success: “Linked <file> → <origin_title>”
   - Failure: clear error (no recent download, Safari not available, etc.)

### Lookup File (later)
**Intent:** “I have this file; where did it come from?”

1. Menu bar → **Lookup File…**
2. File picker opens; user selects any file on disk.
3. App calls `ctx-core lookup` (hash-based).
4. App shows:
   - Captured time
   - Origin title + URL
   - Note
   - Buttons: Open Source Page / Reveal in Finder / Copy URL / Close
5. If not found: “No context saved for this file.”

### Search (minimal)
**Intent:** “I remember keywords; find the record.”

1. Menu bar → **Search…**
2. User types keywords; app calls `ctx-core search` (debounced).
3. Results show time, file name, origin title, note snippet.
4. Selecting a result offers actions:
   - Open Source Page
   - Reveal file in Finder (if path exists)
   - Copy URL / Copy note

### Recent Captures
Menu shows the last 10 captures for quick access.

---

## Data captured (record fields)

Required:
- `id` (UUID)
- `created_at` (unix epoch seconds)
- `file_hash` (SHA-256 hex)
- `file_name`
- `file_size_bytes`
- `file_path_at_capture`
- `origin_title`
- `origin_url`

Optional:
- `note`

Rationale:
- `file_hash` is the stable identity across rename/move.
- `origin_title` is human-meaningful for search.
- `note` stores intent (“assignment”, “evidence”, “v2”).

---

## Storage (SQLite)

DB location (recommended):
- `~/Library/Application Support/Ctx/ctx.sqlite`

### Schema (MVP)
```sql
CREATE TABLE IF NOT EXISTS captures (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  file_hash TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_path_at_capture TEXT NOT NULL,
  origin_title TEXT NOT NULL,
  origin_url TEXT NOT NULL,
  note TEXT
);

CREATE INDEX IF NOT EXISTS idx_captures_file_hash ON captures(file_hash);
CREATE INDEX IF NOT EXISTS idx_captures_created_at ON captures(created_at);
CREATE INDEX IF NOT EXISTS idx_captures_origin_title ON captures(origin_title);
```

(FTS5 is a future enhancement.)

---

## Browser support (MVP)

### Safari (required)
Must capture at capture-time:
- **Active tab title**
- **Active tab URL**

Implementation: AppleScript via `osascript` (or ScriptingBridge).

Failure behavior:
- If Safari isn’t running, no window, or no active tab:
  - Capture should fail gracefully: `Safari not available or no active tab.`

### Other browsers (out of scope for MVP)
Chrome/Brave/Edge/Firefox not required for MVP.

---

## Python core (ctx-core) specification

### Packaging
- Build `ctx-core` as a **single macOS executable** using **PyInstaller**.
- For the app distribution, embed at:
  - `Ctx.app/Contents/MacOS/ctx-core`

### Command interface (JSON)
All commands output JSON to stdout.
- Exit code `0` on success
- Non-zero on failure (still output JSON)

#### `ctx-core capture`
Inputs:
- `--downloads-dir <path>` (default `~/Downloads`)
- `--within <seconds>` (default 60)
- `--origin-title "<title>"` (required; provided by Swift app)
- `--origin-url "<url>"` (required; provided by Swift app)
- `--note "<text>"` (optional)

Behavior:
1. Find newest file created within window.
2. Hash (SHA-256) using streaming chunks.
3. Insert record into SQLite.
4. Output JSON summary.

Failure codes:
- `NO_RECENT_DOWNLOAD`
- `SAFARI_CONTEXT_MISSING` (if Swift didn’t provide origin fields)
- `DB_ERROR`
- `HASH_ERROR`

#### `ctx-core lookup`
Inputs:
- `--path <file_path>` (required)

Behavior:
1. Hash file.
2. Query by `file_hash`.
3. Return the most recent record if multiple.

#### `ctx-core search`
Inputs:
- `--q "<query>"` (required; allow empty string for “recent”)
- `--limit <n>` (default 20)

Behavior:
- Case-insensitive `LIKE` search across `origin_title`, `origin_url`, `note`, `file_name`.
- Return list of summaries.

---

## CLI contract (ctx) — required commands

The CLI can be implemented as a thin wrapper around `ctx-core`.

### `ctx capture`
- For CLI mode, `ctx` itself may obtain Safari title/URL (AppleScript) and pass them to `ctx-core capture`,
  OR it can call a small helper to fetch Safari context.
Options:
- `--downloads-dir <path>` (default `~/Downloads`)
- `--within <seconds>` (default `60`)
- `--note "<text>"` (optional)
- `--no-note` (skip prompt)

### `ctx lookup <file_path>`
Hash-based lookup and print record details.

### `ctx search <query>`
Search records; print results list with IDs.

### `ctx open <id>`
Open origin URL in default browser.

### `ctx reveal <file_path>` (or `ctx reveal-id <id>`)
Reveal file in Finder.

---

## Swift wrapper (Ctx.app) requirements

### Menu bar integration
- Use `NSStatusItem` (AppKit) or SwiftUI lifecycle + status item.

### Safari context capture (MVP)
Swift obtains:
- active tab title
- active tab URL
and passes them to `ctx-core capture`.

### Calling ctx-core
- Locate bundled executable:
  - `Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("ctx-core")`
- Launch with `Process`, parse stdout JSON, show UI.

### UI screens (MVP)
- Capture dialog
- Lookup result dialog
- Search window (simple list)
- Settings (downloads dir, within seconds)

---

## Permissions & privacy
- Local-only storage, no network transmission required.
- macOS Automation permission may be requested to read Safari tab data.
- No Accessibility permission needed for MVP.

---

## Edge cases & expected behavior
- No recent download: show a clear error (“No file created in Downloads within last 60 seconds.”)
- Multiple downloads: choose newest by time.
- Large files: chunked hashing.
- File moved/renamed: lookup still works via hash.
- Duplicate identical files: allow multiple records; lookup returns most recent.

---

## Definition of Done (MVP)
- Prebuilt `Ctx.app.zip` runs as a menu bar app and supports Capture/Lookup/Search without Terminal.
- CLI `ctx` can perform capture/lookup/search/open/reveal.
- Both modes use the same SQLite DB and produce consistent results.
- Safari-only origin capture works reliably with clear failure messages.

---

## Repo layout recommendation (Codex-friendly)
```
repo/
  README.md
  app-swift/
    Ctx.xcodeproj (or workspace)
    Sources/...
  core-python/
    ctx_core/...
    pyproject.toml (optional)
    pyinstaller.spec
  cli/
    ctx (entrypoint wrapper)  # or Python package console_script
  scripts/
    build_core.sh
    build_app.sh
    package_app.sh
    build_cli.sh
  docs/
    permissions.md
```

### Release artifacts (suggested)
- `Ctx.app.zip` (menu bar app)
- `ctx-cli.zip` (standalone CLI bundle) OR `ctx` binary
- Checksums file (optional)
