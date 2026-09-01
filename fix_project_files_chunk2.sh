#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"

echo "============================================================"
echo "TRAVELER DEV — PROJECT FILES FINAL VALIDATION"
echo "============================================================"

echo
echo "=== JAVASCRIPT SYNTAX ==="

node --check src/project-files.js
echo "PASS  src/project-files.js"

node --check src/main.js
echo "PASS  src/main.js"

if [ -f src/stackblitz.js ]; then
  node --check src/stackblitz.js
  echo "PASS  src/stackblitz.js"
fi

echo
echo "=== PACKAGE ==="

node -e '
const p = require("./package.json");
if (!p.scripts || !p.scripts.build) {
  throw new Error("package.json does not contain a build script");
}
console.log("PASS  package.json");
console.log("BUILD:", p.scripts.build);
'

echo
echo "=== NPM CACHE ==="

npm cache verify >/dev/null
echo "PASS  npm cache"

echo
echo "=== DEPENDENCIES ==="

if [ ! -d node_modules ]; then
  echo "node_modules missing"
  echo "Installing frontend dependencies..."

  npm install --no-audit --no-fund
else
  echo "PASS  node_modules exists"
fi

echo
echo "=== PRODUCTION BUILD ==="

npm run build

test -f dist/index.html
echo "PASS  dist/index.html"

echo
echo "=== PWA ==="

test -f public/manifest.webmanifest
echo "PASS  manifest.webmanifest"

test -f public/sw.js
echo "PASS  sw.js"

echo
echo "=== BUILD OUTPUT ==="

du -sh dist
find dist -maxdepth 2 -type f | sort | head -80

echo
echo "============================================================"
echo "TRAVELER DEV FRONTEND BUILD: PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "PWA:      $FRONTEND/public/manifest.webmanifest"
echo "SW:       $FRONTEND/public/sw.js"
echo "============================================================"
