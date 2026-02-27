# Ctx — Download Context Linker (macOS)
**Swift Menu Bar App + Python Core + Optional CLI (Open Source)**

## One-sentence goal
When you download a file, Ctx lets you capture its **origin webpage (title + URL)** plus an optional **note**, so later you can **look up any local file** (even renamed/moved) and instantly see **where/why you got it**.

---

## What users can do (distribution + usage options)

### Option A — Download a prebuilt app (non-technical)
- Go to **GitHub Releases** and download **Ctx.app.zip**.
- Drag **Ctx.app** into **/Applications**.
- Open it -> a **menu bar icon** appears.
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

> **Shared storage:** App and CLI use the same SQLite database by default.

DB path resolution order (app and CLI):
1. `CTX_DB_PATH` env var (if set)
2. `~/Library/Application Support/Ctx/ctx.sqlite`

---

## Non-negotiable constraints
- Core mapping: **local file <-> origin webpage (title + URL) + timestamp + note**.
- Lookup must survive rename/move via **SHA-256 file hash**.
- Storage is **local-only** (SQLite in Application Support unless overridden).
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
- Download candidate detection, hashing, SQLite read/write, search.
- Exposes a stable versioned JSON CLI interface: `capture`, `lookup`, `search`.
- No UI.

3) **CLI (ctx) — optional front-end**
- A small user-facing CLI wrapper that either:
  - calls `ctx-core`, or
  - imports the same Python package (implementation choice).
- Provides the CLI contract described below.

### Communication
- Swift runs `ctx-core` via `Process()` and passes arguments.
- `ctx-core` prints JSON to stdout; Swift parses and displays results.

### Shared domain model
All interfaces should align on these entities:
- `CaptureRecord`
- `SearchResult`
- `CtxError`

---

## Core user workflows (MVP)

### Capture Latest Download (primary)
**Intent:** "I just downloaded something; remember where it came from."

1. User downloads a file in Safari.
2. User triggers capture:
   - Menu bar -> **Capture Latest Download...**
   - (Optional) global hotkey (configurable; v1.1 if needed)
3. App/core detects candidate file(s) in `~/Downloads` within `N` seconds (default 60).
4. Core validates candidate is complete/stable:
   - Ignore known temporary/incomplete names (`.download`, `.part`, etc.)
   - Poll size/mtime briefly (for example, 2 checks) and require no change
5. App reads Safari active tab:
   - `origin_title`
   - `origin_url`
6. App shows a Capture dialog:
   - Detected file name (and optional path)
   - Origin page title (clickable) + URL (copy button)
   - Note (optional, single line)
   - Buttons: Save / Cancel
7. On Save, app calls `ctx-core capture` and shows a toast:
   - Success: `Linked <file> -> <origin_title>`
   - Failure: clear error (no recent stable download, Safari not available, etc.)

### Lookup File (later)
**Intent:** "I have this file; where did it come from?"

1. Menu bar -> **Lookup File...**
2. File picker opens; user selects any file on disk.
3. App calls `ctx-core lookup` (hash-based).
4. App shows:
   - One or more matching records (newest first)
   - For selected record: captured time, origin title + URL, note
   - Buttons: Open Source Page / Reveal in Finder / Copy URL / Close
5. If not found: `No context saved for this file.`

### Search (minimal)
**Intent:** "I remember keywords; find the record."

1. Menu bar -> **Search...**
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
- `browser` (default `safari`)
- `source_app` (for example `ctx-app` or `ctx-cli`)
- `mime_type` (best effort)

Rationale:
- `file_hash` is the stable identity across rename/move.
- `origin_title` is human-meaningful for search.
- Extra metadata reduces future migration churn.

---

## Storage (SQLite)

DB location (default):
- `~/Library/Application Support/Ctx/ctx.sqlite`

### Runtime pragmas
- `PRAGMA journal_mode=WAL;`
- `PRAGMA foreign_keys=ON;`

### Schema (MVP)
```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS captures (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  file_hash TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_path_at_capture TEXT NOT NULL,
  origin_title TEXT NOT NULL,
  origin_url TEXT NOT NULL,
  note TEXT,
  browser TEXT,
  source_app TEXT,
  mime_type TEXT
);

CREATE INDEX IF NOT EXISTS idx_captures_file_hash ON captures(file_hash);
CREATE INDEX IF NOT EXISTS idx_captures_created_at ON captures(created_at);
```

### Search indexing
- MVP should use SQLite **FTS5** for `origin_title`, `origin_url`, `note`, and `file_name`.
- If FTS5 is unavailable in a specific build, fallback to case-insensitive `LIKE` and return a clear diagnostic in logs.

### Migration policy
- Schema changes must be forward-migrated using numbered migration scripts.
- App/core startup runs pending migrations in a transaction before normal operations.

---

## Browser support (MVP)

### Safari (required)
Must capture at capture-time:
- **Active tab title**
- **Active tab URL**

Implementation: AppleScript via `osascript` (or ScriptingBridge).

Failure behavior:
- If Safari is not running, no window, or no active tab:
  - Capture fails gracefully: `Safari not available or no active tab.`

### Other browsers (out of scope for MVP)
Chrome/Brave/Edge/Firefox not required for MVP.

---

## Python core (ctx-core) specification

### Packaging
- Build `ctx-core` as a **single macOS executable** using **PyInstaller**.
- Build target must be **universal2** for release artifacts.
- For the app distribution, embed at:
  - `Ctx.app/Contents/MacOS/ctx-core`

### Command interface (versioned JSON)
All commands output JSON to stdout.
- Exit code `0` on success
- Non-zero on failure (still output JSON)
- Every response must include `schema_version` (integer, starting at `1`)

Success shape:
```json
{
  "schema_version": 1,
  "ok": true,
  "data": { }
}
```

Failure shape:
```json
{
  "schema_version": 1,
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": {}
  }
}
```

#### `ctx-core capture`
Inputs:
- `--downloads-dir <path>` (default `~/Downloads`)
- `--within <seconds>` (default 60)
- `--origin-title "<title>"` (required; provided by Swift app)
- `--origin-url "<url>"` (required; provided by Swift app)
- `--note "<text>"` (optional)
- `--source-app <ctx-app|ctx-cli>` (optional)

Behavior:
1. Find newest stable file created within window.
2. Hash (SHA-256) using streaming chunks.
3. Insert record into SQLite in a transaction.
4. Output JSON summary.

Failure codes:
- `NO_RECENT_DOWNLOAD`
- `DOWNLOAD_NOT_STABLE`
- `SAFARI_CONTEXT_MISSING`
- `DB_ERROR`
- `HASH_ERROR`

#### `ctx-core lookup`
Inputs:
- `--path <file_path>` (required)
- `--limit <n>` (default 20)

Behavior:
1. Hash file.
2. Query by `file_hash`.
3. Return all matching records, newest first.

#### `ctx-core search`
Inputs:
- `--q "<query>"` (required; allow empty string for "recent")
- `--limit <n>` (default 20)

Behavior:
- Query via FTS5 (or fallback LIKE).
- Return list of summaries.

---

## CLI contract (ctx) — required commands

The CLI can be implemented as a thin wrapper around `ctx-core`.

### `ctx capture`
- For CLI mode, `ctx` may obtain Safari title/URL (AppleScript) and pass them to `ctx-core capture`,
  OR it can call a small helper to fetch Safari context.
Options:
- `--downloads-dir <path>` (default `~/Downloads`)
- `--within <seconds>` (default `60`)
- `--note "<text>"` (optional)
- `--no-note` (skip prompt)

### `ctx lookup <file_path>`
Hash-based lookup and print matching records (newest first).

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
- No recent download: show a clear error (`No file created in Downloads within last 60 seconds.`)
- Incomplete or still-writing download: show `Download not stable yet` and let user retry.
- Multiple downloads: choose newest stable file by time.
- Large files: chunked hashing.
- File moved/renamed: lookup still works via hash.
- Duplicate identical files: keep multiple records; lookup returns all matches newest first.

---

## Build, release, and operations

### Build targets
- Release artifacts must include Apple Silicon + Intel support (`universal2`) where applicable.

### CI pipeline (required)
CI should:
1. Run unit tests (core and CLI).
2. Run end-to-end smoke tests (capture -> lookup -> search with fixtures).
3. Build `ctx-core` and CLI artifacts.
4. Build `Ctx.app`.
5. Sign, notarize, and staple `Ctx.app`.
6. Publish release artifacts and checksums.

### Signing/notarization
- Use Developer ID signing for app distribution.
- Notarize and staple release app zips to avoid Gatekeeper friction.

---

## Definition of Done (MVP)
- Prebuilt `Ctx.app.zip` runs as a menu bar app and supports Capture/Lookup/Search without Terminal.
- CLI `ctx` can perform capture/lookup/search/open/reveal.
- Both modes use the same SQLite DB and produce consistent results.
- Safari-only origin capture works reliably with clear failure messages.
- JSON contract is versioned and stable.
- Release app is signed, notarized, and staple-verified.

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
    migrations/
  cli/
    ctx (entrypoint wrapper)  # or Python package console_script
  scripts/
    build_core.sh
    build_app.sh
    package_app.sh
    build_cli.sh
    run_smoke_tests.sh
  docs/
    permissions.md
    json-contract.md
    release.md
```

### Release artifacts (suggested)
- `Ctx.app.zip` (menu bar app)
- `ctx-cli.zip` (standalone CLI bundle) OR `ctx` binary
- `SHA256SUMS.txt`
