#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "TRAVELER DEV — CLOUDFLARE FRONTEND PRODUCTION FIX"
echo "============================================================"

ROOT="$(git rev-parse --show-toplevel)"
FRONTEND="$ROOT/frontend"

cd "$ROOT"

echo
echo "=== VERIFY REPOSITORY ==="

REMOTE="$(git remote get-url origin)"
BRANCH="$(git branch --show-current)"

[[ "$REMOTE" == "https://github.com/dolordprince/Agent-traveler-dev2.git" ]] || {
  echo "ERROR: Wrong GitHub remote:"
  echo "$REMOTE"
  exit 1
}

[[ "$BRANCH" == "main" ]] || {
  echo "ERROR: Must be on main branch. Current: $BRANCH"
  exit 1
}

[[ -d "$FRONTEND" ]] || {
  echo "ERROR: frontend directory does not exist"
  exit 1
}

[[ -f "$FRONTEND/package.json" ]] || {
  echo "ERROR: frontend/package.json missing"
  exit 1
}

[[ -f "$FRONTEND/vite.config.js" ]] || {
  echo "ERROR: frontend/vite.config.js missing"
  exit 1
}

echo "PASS repository"
echo "PASS frontend"

echo
echo "=== CONFIGURE CLOUDFLARE ==="

cd "$FRONTEND"

cat > wrangler.jsonc <<'JSON'
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "agent-traveler-dev2",
  "compatibility_date": "2026-08-28",
  "workers_dev": true,
  "observability": {
    "enabled": true
  },
  "assets": {
    "directory": "./dist",
    "not_found_handling": "single-page-application"
  }
}
JSON

echo "PASS frontend/wrangler.jsonc"

echo
echo "=== PIN WRANGLER ==="

if node -e '
const p=require("./package.json");
process.exit(
  p.devDependencies && p.devDependencies.wrangler
    ? 0
    : 1
);
'; then
  echo "Wrangler already present"
else
  npm install --save-dev wrangler@4.127.1
fi

echo "PASS Wrangler dependency"

echo
echo "=== VERIFY PACKAGE ==="

node - <<'NODE'
const fs = require("fs");

const p = JSON.parse(fs.readFileSync("package.json", "utf8"));

if (!p.scripts || typeof p.scripts.build !== "string") {
  throw new Error("package.json does not contain a build script");
}

if (!p.scripts.build.includes("vite")) {
  throw new Error(`Unexpected build command: ${p.scripts.build}`);
}

if (!p.devDependencies || !p.devDependencies.wrangler) {
  throw new Error("Wrangler is not installed as a dev dependency");
}

console.log("Build:", p.scripts.build);
console.log("Wrangler:", p.devDependencies.wrangler);
NODE

echo "PASS package configuration"

echo
echo "=== PRODUCTION BUILD ==="

rm -rf dist

npm ci
npm run build

[[ -f dist/index.html ]] || {
  echo "ERROR: dist/index.html was not generated"
  exit 1
}

[[ -f dist/manifest.webmanifest ]] || {
  echo "ERROR: dist/manifest.webmanifest was not generated"
  exit 1
}

[[ -f dist/sw.js ]] || {
  echo "ERROR: dist/sw.js was not generated"
  exit 1
}

echo "PASS Vite production build"
echo "PASS dist/index.html"
echo "PASS dist/manifest.webmanifest"
echo "PASS dist/sw.js"

echo
echo "=== VERIFY WRANGLER CONFIG ==="

npx wrangler deploy --dry-run

echo "PASS Cloudflare Wrangler configuration"

echo
echo "=== RETURN TO REPOSITORY ==="

cd "$ROOT"

echo
echo "=== GIT STATUS ==="

git status --short

echo
echo "=== STAGE ONLY DEPLOYMENT FILES ==="

git add frontend/package.json
git add frontend/package-lock.json
git add frontend/wrangler.jsonc

git diff --cached --check

echo "PASS staged files"

echo
echo "=== COMMIT ==="

if git diff --cached --quiet; then
  echo "No deployment changes require committing."
else
  git commit -m "fix: configure Cloudflare frontend deployment"
fi

echo
echo "=== PUSH MAIN ==="

git push origin main

echo
echo "=== VERIFY REMOTE ==="

git fetch origin main

LOCAL="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse origin/main)"

[[ "$LOCAL" == "$REMOTE_HEAD" ]] || {
  echo "ERROR: Remote main does not match local HEAD"
  exit 1
}

echo "PASS GitHub main synchronized"

echo
echo "============================================================"
echo "TRAVELER DEV — CLOUDFLARE FRONTEND FIX: PASS"
echo "============================================================"
echo
echo "Repository:"
echo "  https://github.com/dolordprince/Agent-traveler-dev2"
echo
echo "Frontend:"
echo "  frontend/"
echo
echo "Build output:"
echo "  frontend/dist/"
echo
echo "Cloudflare Worker:"
echo "  agent-traveler-dev2"
echo
echo "Backend:"
echo "  https://agent-traveler-dev2.onrender.com"
echo
echo "============================================================"
