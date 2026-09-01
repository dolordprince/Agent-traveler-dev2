#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"

echo "============================================================"
echo "TRAVELER DEV — STACKBLITZ BRIDGE FINAL BUILD"
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
JS

echo
echo "=== PRODUCTION BUILD ==="

npm run build

echo
echo "=== OUTPUT ==="

test -f dist/index.html
echo "PASS  dist/index.html"

test -f public/manifest.webmanifest
echo "PASS  manifest.webmanifest"

test -f public/sw.js
echo "PASS  sw.js"

echo
echo "============================================================"
echo "TRAVELER DEV FRONTEND: BUILD PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "Bridge:   $FRONTEND/src/stackblitz.js"
echo "Files:    $FRONTEND/src/project-files.js"
echo "PWA:      manifest.webmanifest + sw.js"
echo "============================================================"
