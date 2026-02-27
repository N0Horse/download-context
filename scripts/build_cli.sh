#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
cp "$ROOT/cli/ctx" "$ROOT/dist/ctx"
chmod +x "$ROOT/dist/ctx"

echo "Built CLI at $ROOT/dist/ctx"
