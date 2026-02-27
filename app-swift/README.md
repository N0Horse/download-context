# Ctx Swift App

Buildable menu bar app wrapper around `ctx-core`.

## Build app bundle
From repo root:
```bash
./scripts/build_app.sh
```

Output:
- `dist/Ctx.app`

## Run in development
```bash
swift run --package-path app-swift Ctx
```

For development fallback mode (without bundled `ctx-core`), run from repo root so the app can call `python3 -m ctx_core` using `core-python`.

## Runtime notes
- App tries bundled `ctx-core` first (`Ctx.app/Contents/MacOS/ctx-core`).
- You can override with `CTX_CORE_PATH=/absolute/path/to/ctx-core`.
- For source fallback mode, you can set `CTX_CORE_PYTHON_PATH=/absolute/path/to/core-python`.
