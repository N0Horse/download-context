# Release Process

1. Build `ctx-core` (PyInstaller).
2. Build Swift app and embed `ctx-core` in `Ctx.app/Contents/MacOS/ctx-core`.
3. Sign app with Developer ID.
4. Notarize app zip.
5. Staple notarization ticket.
6. Publish `Ctx.app.zip`, `ctx-cli.zip`, and `SHA256SUMS.txt`.
