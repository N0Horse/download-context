#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/core-python"

python3 -m pip install --upgrade pip pyinstaller
python3 -m PyInstaller --onefile -n ctx-core -p . ctx_core/__main__.py

echo "Built core at core-python/dist/ctx-core"
