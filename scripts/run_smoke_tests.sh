#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DB="$(mktemp /tmp/ctx-smoke-XXXXXX.sqlite)"
TMP_DIR="$(mktemp -d /tmp/ctx-smoke-dl-XXXXXX)"
FILE="$TMP_DIR/sample.txt"

cleanup() {
  rm -f "$TMP_DB"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

export CTX_DB_PATH="$TMP_DB"

echo "smoke" > "$FILE"

echo "[1/3] capture"
PYTHONPATH="$ROOT/core-python" python3 -m ctx_core capture \
  --downloads-dir "$TMP_DIR" \
  --within 60 \
  --origin-title "Example Page" \
  --origin-url "https://example.com" \
  --note "fixture" \
  --source-app "smoke" >/tmp/ctx-capture.json

cat /tmp/ctx-capture.json

echo "[2/3] lookup"
PYTHONPATH="$ROOT/core-python" python3 -m ctx_core lookup --path "$FILE" >/tmp/ctx-lookup.json
cat /tmp/ctx-lookup.json

echo "[3/3] search"
PYTHONPATH="$ROOT/core-python" python3 -m ctx_core search --q "example" >/tmp/ctx-search.json
cat /tmp/ctx-search.json

echo "Smoke test complete"
