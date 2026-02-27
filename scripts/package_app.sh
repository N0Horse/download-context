#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

"$ROOT/scripts/build_app.sh"
"$ROOT/scripts/build_cli.sh"

cd "$DIST"
rm -f Ctx.app.zip ctx-cli.zip SHA256SUMS.txt

/usr/bin/zip -r Ctx.app.zip Ctx.app >/dev/null
/usr/bin/zip -j ctx-cli.zip ctx >/dev/null

shasum -a 256 Ctx.app.zip ctx-cli.zip ctx-core > SHA256SUMS.txt

echo "Packaged artifacts in $DIST"
ls -lh Ctx.app.zip ctx-cli.zip ctx-core SHA256SUMS.txt
