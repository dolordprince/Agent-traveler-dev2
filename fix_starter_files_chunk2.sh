#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"

echo "============================================================"
echo "TRAVELER DEV — STARTER PROJECT FILES BUILD FIX"
echo "============================================================"

echo
echo "=== SYNTAX ==="

node --check src/project-files.js
echo "PASS  project-files.js"

node --check src/main.js
echo "PASS  main.js"

node --check src/stackblitz.js
echo "PASS  stackblitz.js"

echo
echo "=== EXPORT CHECK ==="

node --input-type=module <<'JS'
import { starterProjectFiles } from "./src/project-files.js";

if (!starterProjectFiles || typeof starterProjectFiles !== "object") {
  throw new Error("starterProjectFiles is not an object");
}

const required = [
  "index.html",
  "package.json",
  "src/main.js"
];

for (const file of required) {
  if (typeof starterProjectFiles[file] !== "string") {
    throw new Error("Missing starter project file: " + file);
  }
}

console.log("PASS  starterProjectFiles");
console.log("FILES:", Object.keys(starterProjectFiles).length);
JS

echo
echo "=== PRODUCTION BUILD ==="

npm run build

echo
echo "=== BUILD VERIFICATION ==="

test -f dist/index.html
echo "PASS  dist/index.html"

test -d dist
echo "PASS  dist directory"

echo
echo "============================================================"
echo "TRAVELER DEV FRONTEND BUILD: PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "PWA:      $FRONTEND/public/manifest.webmanifest"
echo "SW:       $FRONTEND/public/sw.js"
echo "StackBlitz bridge: $FRONTEND/src/stackblitz.js"
echo "Project files:     $FRONTEND/src/project-files.js"
echo "============================================================"
