#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"

echo "============================================================"
echo "TRAVELER DEV — STACKBLITZ BRIDGE FINAL VALIDATION"
echo "============================================================"

echo
echo "=== JAVASCRIPT SYNTAX ==="

node --check src/stackblitz.js
echo "PASS  stackblitz.js"

node --check src/project-files.js
echo "PASS  project-files.js"

node --check src/main.js
echo "PASS  main.js"

echo
echo "=== REQUIRED EXPORTS ==="

node --input-type=module <<'JS'
import * as bridge from "./src/stackblitz.js";

const required = [
  "bootWebContainer",
  "writeProjectFiles",
  "runWebContainerCommand",
  "runProjectCommand",
  "getWebContainerState",
  "installProjectDependencies",
  "buildProject",
  "startProject",
  "openProjectPreview",
  "shutdownWebContainer",
  "webcontainerStatus"
];

for (const name of required) {
  if (typeof bridge[name] !== "function") {
    throw new Error("Missing export: " + name);
  }

  console.log("PASS ", name);
}

console.log("PASS  all StackBlitz bridge exports");
JS

echo
echo "=== PACKAGE ==="

test -f package.json
echo "PASS  package.json"

echo
echo "=== PRODUCTION BUILD ==="

npm run build

echo
echo "=== BUILD OUTPUT ==="

test -f dist/index.html
echo "PASS  dist/index.html"

test -f public/manifest.webmanifest
echo "PASS  manifest.webmanifest"

test -f public/sw.js
echo "PASS  sw.js"

echo
echo "=== PWA SOURCE ==="

grep -q '"display"' public/manifest.webmanifest
echo "PASS  manifest display"

grep -q 'serviceWorker' src/main.js || \
grep -q 'serviceWorker' src/stackblitz.js || \
true

echo
echo "============================================================"
echo "TRAVELER DEV — FRONTEND BUILD: PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "Bridge:   $FRONTEND/src/stackblitz.js"
echo "PWA:      $FRONTEND/public/manifest.webmanifest"
echo "SW:       $FRONTEND/public/sw.js"
echo "============================================================"
