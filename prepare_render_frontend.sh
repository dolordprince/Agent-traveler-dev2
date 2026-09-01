#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRONTEND="$ROOT/frontend"

echo "============================================================"
echo "TRAVELER DEV — PREPARE RENDER FRONTEND"
echo "============================================================"

test -d "$FRONTEND"
test -f "$FRONTEND/package.json"

cd "$FRONTEND"

cat > .env.production <<'ENVEOF'
VITE_WORKSPACE_API_URL=https://agent-traveler-dev2.onrender.com
ENVEOF

echo "PASS .env.production"

echo
echo "=== SYNTAX ==="

node --check src/main.js
echo "PASS main.js"

node --check src/stackblitz.js
echo "PASS stackblitz.js"

node --check src/project-files.js
echo "PASS project-files.js"

node --check src/workspace-api.js
echo "PASS workspace-api.js"

echo
echo "=== BUILD ==="

npm ci
npm run build

test -f dist/index.html
test -f dist/manifest.webmanifest
test -f dist/sw.js

echo "PASS production build"

echo
echo "=== API CONFIG ==="

grep -R "agent-traveler-dev2.onrender.com" \
  dist \
  >/dev/null

echo "PASS backend URL embedded in production build"

echo
echo "============================================================"
echo "TRAVELER DEV — RENDER FRONTEND PREPARED: PASS"
echo "============================================================"
