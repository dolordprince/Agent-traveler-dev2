#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRONTEND="$ROOT/frontend"

echo "============================================================"
echo "TRAVELER DEV — FRONTEND RENDER DEPLOYMENT PRECHECK"
echo "============================================================"

cd "$ROOT"

echo
echo "=== REPOSITORY ==="
REMOTE_URL="$(git remote get-url origin)"
BRANCH="$(git branch --show-current)"
COMMIT="$(git rev-parse HEAD)"

echo "Remote: $REMOTE_URL"
echo "Branch: $BRANCH"
echo "Commit: $COMMIT"

echo
echo "=== FRONTEND FILES ==="
required_files=(
  "frontend/package.json"
  "frontend/package-lock.json"
  "frontend/index.html"
  "frontend/vite.config.js"
  "frontend/src/main.js"
  "frontend/src/stackblitz.js"
  "frontend/src/project-files.js"
  "frontend/src/workspace-api.js"
  "frontend/src/style.css"
  "frontend/public/manifest.webmanifest"
  "frontend/public/sw.js"
  "frontend/public/icon.svg"
)

for file in "${required_files[@]}"; do
  test -f "$ROOT/$file"
  echo "PASS $file"
done

echo
echo "=== JAVASCRIPT SYNTAX ==="
node --check "$FRONTEND/src/main.js"
echo "PASS main.js"

node --check "$FRONTEND/src/stackblitz.js"
echo "PASS stackblitz.js"

node --check "$FRONTEND/src/project-files.js"
echo "PASS project-files.js"

node --check "$FRONTEND/src/workspace-api.js"
echo "PASS workspace-api.js"

echo
echo "=== PACKAGE ==="
cd "$FRONTEND"

node - <<'NODE'
const fs = require("fs");

const p = JSON.parse(fs.readFileSync("package.json", "utf8"));

if (!p.scripts || p.scripts.build !== "vite build") {
  throw new Error("package.json build script must be vite build");
}

console.log("PASS package.json");
console.log("BUILD:", p.scripts.build);
NODE

echo
echo "=== PRODUCTION BUILD ==="
npm run build

test -f dist/index.html
test -f dist/manifest.webmanifest
test -f dist/sw.js

echo "PASS dist/index.html"
echo "PASS dist/manifest.webmanifest"
echo "PASS dist/sw.js"

echo
echo "=== PWA ==="
node - <<'NODE'
const fs = require("fs");

const manifest = JSON.parse(
  fs.readFileSync("dist/manifest.webmanifest", "utf8")
);

if (manifest.display !== "standalone") {
  throw new Error("PWA manifest must use standalone display");
}

if (!manifest.start_url) {
  throw new Error("PWA manifest missing start_url");
}

if (!Array.isArray(manifest.icons) || manifest.icons.length === 0) {
  throw new Error("PWA manifest missing icons");
}

console.log("PASS PWA manifest");
console.log("display:", manifest.display);
console.log("start_url:", manifest.start_url);
NODE

echo
echo "=== STACKBLITZ BRIDGE EXPORTS ==="

node --input-type=module - <<'NODE'
const mod = await import("./src/stackblitz.js");

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
  if (!(name in mod)) {
    throw new Error(`Missing StackBlitz export: ${name}`);
  }

  console.log(`PASS ${name}`);
}
NODE

echo
echo "=== PROJECT FILES ==="

node --input-type=module - <<'NODE'
const mod = await import("./src/project-files.js");

if (!mod.starterProjectFiles) {
  throw new Error("starterProjectFiles export missing");
}

if (typeof mod.starterProjectFiles !== "object") {
  throw new Error("starterProjectFiles must be an object");
}

console.log("PASS starterProjectFiles");
console.log("FILES:", Object.keys(mod.starterProjectFiles).length);
NODE

echo
echo "=== GIT REMOTE ==="
cd "$ROOT"

REMOTE_COMMIT="$(
  git ls-remote origin "refs/heads/$BRANCH" |
  awk '{print $1}'
)"

if [ "$REMOTE_COMMIT" != "$COMMIT" ]; then
  echo "FAIL GitHub remote does not match local commit"
  echo "LOCAL : $COMMIT"
  echo "REMOTE: $REMOTE_COMMIT"
  exit 1
fi

echo "PASS GitHub remote matches local"

echo
echo "============================================================"
echo "TRAVELER DEV — FRONTEND DEPLOYMENT PACKAGE: PASS"
echo "============================================================"
echo
echo "Root:     $ROOT"
echo "Frontend: $FRONTEND"
echo "Branch:   $BRANCH"
echo "Commit:   $COMMIT"
echo
echo "Render configuration:"
echo "Root Directory: frontend"
echo "Build Command:  npm ci && npm run build"
echo "Publish Dir:    dist"
echo
echo "Next: create/update the Render Static Site using these values."
echo "============================================================"
