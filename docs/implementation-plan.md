# Ctx Implementation Plan (MVP)

This checklist is ordered to minimize rework and make each layer testable before moving on.

## 1. Project Bootstrap
- [ ] Create repository structure:
  - `app-swift/`
  - `core-python/`
  - `cli/`
  - `scripts/`
  - `docs/`
- [ ] Add top-level `README.md` with build and run entrypoints.
- [ ] Define canonical DB path resolution in one place:
  - `CTX_DB_PATH`
  - fallback `~/Library/Application Support/Ctx/ctx.sqlite`

## 2. Core Domain + Contract
- [ ] Create `docs/json-contract.md` with:
  - `schema_version`
  - success envelope (`ok: true`, `data`)
  - error envelope (`ok: false`, `error.code`, `error.message`, `error.details`)
- [ ] Define domain entities used by app/CLI/core:
  - `CaptureRecord`
  - `SearchResult`
  - `CtxError`
- [ ] Freeze initial `schema_version = 1` and backward-compatibility rule.

## 3. SQLite Layer (core-python)
- [ ] Build DB bootstrap that ensures parent directory exists.
- [ ] Enable runtime pragmas:
  - `PRAGMA journal_mode=WAL;`
  - `PRAGMA foreign_keys=ON;`
- [ ] Implement migration runner with `schema_migrations` table.
- [ ] Add migration `0001_initial.sql` for `captures` table and indexes.
- [ ] Add migration test: clean DB upgrades to latest successfully.

## 4. Capture Engine (core-python)
- [ ] Implement candidate scan in downloads dir within `--within` seconds.
- [ ] Filter temp/incomplete files (`.download`, `.part`, etc.).
- [ ] Implement stability check (size/mtime unchanged across 2 polls).
- [ ] Hash file with chunked SHA-256.
- [ ] Insert capture in one DB transaction.
- [ ] Return JSON result with created record summary.
- [ ] Return explicit errors:
  - `NO_RECENT_DOWNLOAD`
  - `DOWNLOAD_NOT_STABLE`
  - `SAFARI_CONTEXT_MISSING`
  - `DB_ERROR`
  - `HASH_ERROR`

## 5. Lookup + Search Engine (core-python)
- [ ] `lookup --path <file>` hashes input and returns all matches by `file_hash` newest first.
- [ ] `search --q --limit` implemented with FTS5.
- [ ] Add fallback to case-insensitive `LIKE` if FTS5 unavailable.
- [ ] Ensure stable sorting by `created_at DESC`.

## 6. ctx-core CLI Surface
- [ ] Implement subcommands:
  - `capture`
  - `lookup`
  - `search`
- [ ] Ensure every command prints JSON only to stdout.
- [ ] Ensure non-zero exit codes on failures with JSON error body.
- [ ] Add golden tests for JSON output format.

## 7. User CLI (ctx)
- [ ] Implement wrapper commands:
  - `ctx capture`
  - `ctx lookup <file_path>`
  - `ctx search <query>`
  - `ctx open <id>`
  - `ctx reveal <file_path>` / `ctx reveal-id <id>`
- [ ] Implement Safari context fetch for CLI capture mode.
- [ ] Add human-readable terminal formatting for lookup/search while preserving machine parse option if needed.

## 8. Swift Menu Bar App
- [ ] Build status item shell and menu actions.
- [ ] Implement Safari tab title/URL fetch in Swift.
- [ ] Implement `Process` bridge to bundled `ctx-core` and JSON decode.
- [ ] Build MVP UI:
  - Capture dialog
  - Lookup dialog
  - Search window
  - Settings (downloads dir, within seconds)
- [ ] Add clear user-facing error messages mapped from `CtxError`.

## 9. Packaging
- [ ] Add PyInstaller config for `ctx-core`.
- [ ] Produce `universal2` release binaries where applicable.
- [ ] Bundle `ctx-core` in `Ctx.app/Contents/MacOS/ctx-core`.
- [ ] Package artifacts:
  - `Ctx.app.zip`
  - `ctx-cli.zip` (or standalone `ctx`)
  - `SHA256SUMS.txt`

## 10. macOS Distribution Hardening
- [ ] Configure Developer ID signing for app artifacts.
- [ ] Notarize and staple `Ctx.app.zip` release.
- [ ] Validate Gatekeeper flow on a clean machine/user profile.

## 11. CI/CD
- [ ] Add CI jobs:
  - unit tests (core + CLI)
  - migration tests
  - smoke tests
  - build core/app/cli
- [ ] Add release workflow:
  - sign
  - notarize
  - staple
  - publish GitHub release assets
  - publish checksums

## 12. Test Matrix
- [ ] Core unit tests:
  - hashing
  - stable file detection
  - error code mapping
  - migration runner
- [ ] Integration tests:
  - capture -> lookup
  - capture -> search
  - duplicate hash behavior
- [ ] App smoke tests:
  - Safari available
  - Safari unavailable
  - no recent download
- [ ] Manual QA:
  - rename/move file then lookup succeeds
  - multiple identical files return ordered matches

## 13. Documentation
- [ ] `docs/permissions.md` for Automation permission behavior.
- [ ] `docs/json-contract.md` for response schema.
- [ ] `docs/release.md` for local release and notarization steps.
- [ ] Update `README.md` quickstarts:
  - prebuilt app
  - developer build
  - CLI-only usage

## 14. MVP Exit Criteria
- [ ] App supports Capture/Lookup/Search without Terminal.
- [ ] CLI supports capture/lookup/search/open/reveal.
- [ ] App and CLI share one DB and return consistent results.
- [ ] Safari capture path is reliable with clear failures.
- [ ] JSON contract is stable and versioned.
- [ ] Signed, notarized, stapled app is published.
