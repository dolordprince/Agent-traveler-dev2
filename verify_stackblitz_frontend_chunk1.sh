#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRONTEND="$ROOT/frontend"
SRC="$FRONTEND/src"

echo "============================================================"
echo "TRAVELER DEV — REAL STACKBLITZ FRONTEND VERIFICATION"
echo "============================================================"

test -d "$FRONTEND" || { echo "FAIL frontend directory"; exit 1; }

echo
echo "=== REQUIRED FRONTEND FILES ==="

for file in \
  "$FRONTEND/index.html" \
  "$FRONTEND/package.json" \
  "$FRONTEND/vite.config.js" \
  "$SRC/main.js" \
  "$SRC/style.css" \
  "$SRC/stackblitz.js" \
  "$SRC/project-files.js" \
  "$FRONTEND/public/manifest.webmanifest" \
  "$FRONTEND/public/sw.js" \
  "$FRONTEND/public/icon.svg"
do
  test -f "$file" || {
    echo "FAIL missing: $file"
    exit 1
  }
  echo "PASS $(basename "$file")"
done

echo
echo "=== JAVASCRIPT SYNTAX ==="

node --check "$SRC/main.js"
echo "PASS main.js"

node --check "$SRC/stackblitz.js"
echo "PASS stackblitz.js"

node --check "$SRC/project-files.js"
echo "PASS project-files.js"

echo
echo "=== STACKBLITZ EXPORTS ==="

node --input-type=module <<'NODE'
const fs = await import('./frontend/src/stackblitz.js');

const required = [
  'bootWebContainer',
  'writeProjectFiles',
  'runWebContainerCommand',
  'runProjectCommand',
  'getWebContainerState',
  'installProjectDependencies',
  'buildProject',
  'startProject',
  'openProjectPreview',
  'shutdownWebContainer',
  'webcontainerStatus'
];

for (const name of required) {
  if (!(name in fs)) {
    console.error(`FAIL missing export: ${name}`);
    process.exit(1);
  }
  console.log(`PASS ${name}`);
}

console.log('PASS all StackBlitz bridge exports');
NODE

echo
echo "=== PROJECT FILE EXPORT ==="

node --input-type=module <<'NODE'
const mod = await import('./frontend/src/project-files.js');

if (!mod.starterProjectFiles) {
  console.error('FAIL starterProjectFiles export');
  process.exit(1);
}

if (!Array.isArray(mod.starterProjectFiles) &&
    typeof mod.starterProjectFiles !== 'object') {
  console.error('FAIL starterProjectFiles format');
  process.exit(1);
}

console.log('PASS starterProjectFiles');
NODE

echo
echo "=== ENVIRONMENT ==="

if [ -f "$FRONTEND/.env.production" ]; then
  echo "PASS .env.production exists"
else
  echo "INFO .env.production not present"
fi

echo
echo "=== PRODUCTION BUILD ==="

cd "$FRONTEND"

if [ ! -d node_modules ]; then
  echo "FAIL node_modules missing"
  echo "Run npm install inside frontend before continuing."
  exit 1
fi

npm run build

test -f dist/index.html || {
  echo "FAIL dist/index.html"
  exit 1
}

test -f dist/manifest.webmanifest || {
  echo "FAIL dist/manifest.webmanifest"
  exit 1
}

test -f dist/sw.js || {
  echo "FAIL dist/sw.js"
  exit 1
}

echo
echo "============================================================"
echo "CHUNK 1: PASS"
echo "============================================================"
echo "Real frontend source verified."
echo "StackBlitz bridge exports verified."
echo "Production build verified."
echo
echo "NEXT: run verify_stackblitz_frontend_chunk2.sh"
echo "============================================================"
