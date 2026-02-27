#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/dist"
mkdir -p "$OUT_DIR"

cd "$ROOT/core-python"

if python3 -c "import PyInstaller" >/dev/null 2>&1; then
  python3 -m PyInstaller --clean --noconfirm --onefile -n ctx-core -p . ctx_core/__main__.py
  cp "dist/ctx-core" "$OUT_DIR/ctx-core"
  chmod +x "$OUT_DIR/ctx-core"
  echo "Built standalone core at $OUT_DIR/ctx-core"
else
  cat > "$OUT_DIR/ctx-core" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT/core-python${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m ctx_core "$@"
EOS
  chmod +x "$OUT_DIR/ctx-core"
  echo "PyInstaller not available; built dev wrapper at $OUT_DIR/ctx-core"
fi
