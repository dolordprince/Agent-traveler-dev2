#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FILE="$ROOT/frontend/src/stackblitz.js"

python - "$FILE" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

old = '''const API_URL =
  import.meta.env.VITE_STACKBLITZ_API_URL ||
  import.meta.env.VITE_WORKSPACE_API_URL ||
  "";'''

new = '''const ENV =
  typeof import.meta !== "undefined" &&
  import.meta.env
    ? import.meta.env
    : {};

const API_URL =
  ENV.VITE_STACKBLITZ_API_URL ||
  ENV.VITE_WORKSPACE_API_URL ||
  "";'''

if old not in s:
    raise SystemExit("ERROR: expected API_URL block was not found")

p.write_text(s.replace(old, new))
PY

echo "PASS stackblitz.js environment guard"
node --check "$FILE"
echo "PASS stackblitz.js syntax"
