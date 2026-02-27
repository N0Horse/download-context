#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p dist
cp cli/ctx dist/ctx
chmod +x dist/ctx

echo "Built CLI at dist/ctx"
