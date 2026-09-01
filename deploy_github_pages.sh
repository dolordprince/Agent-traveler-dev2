#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRONTEND="$ROOT/frontend"
WORKFLOW="$ROOT/.github/workflows/deploy-pages.yml"

echo "============================================================"
echo "TRAVELER DEV — GITHUB PAGES DEPLOYMENT"
echo "============================================================"

cd "$ROOT"

test -d "$FRONTEND"
test -f "$FRONTEND/package.json"
test -f "$FRONTEND/vite.config.js"

echo
echo "=== VITE CONFIG ==="

node - <<'NODE'
const fs = require("fs");

const file = "frontend/vite.config.js";
let source = fs.readFileSync(file, "utf8");

if (source.includes("base:")) {
  source = source.replace(
    /base\s*:\s*['"][^'"]*['"]/,
    "base: '/Agent-traveler-dev2/'"
  );
} else {
  source = source.replace(
    /defineConfig\(\{/,
    "defineConfig({\n  base: '/Agent-traveler-dev2/',"
  );
}

fs.writeFileSync(file, source);
console.log("PASS Vite base path");
NODE

echo
echo "=== GITHUB ACTIONS WORKFLOW ==="

mkdir -p "$ROOT/.github/workflows"

cat > "$WORKFLOW" <<'YAML'
name: Deploy Traveler Dev Frontend to GitHub Pages

on:
  push:
    branches:
      - main
    paths:
      - "frontend/**"
      - ".github/workflows/deploy-pages.yml"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: github-pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest

    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    defaults:
      run:
        working-directory: frontend

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Setup Node
        uses: actions/setup-node@v6
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Build frontend
        env:
          VITE_WORKSPACE_API_URL: https://agent-traveler-dev2.onrender.com
        run: npm run build

      - name: Verify production output
        run: |
          test -f dist/index.html
          test -f dist/manifest.webmanifest
          test -f dist/sw.js

      - name: Setup GitHub Pages
        uses: actions/configure-pages@v6

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: frontend/dist

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
YAML

echo "PASS GitHub Pages workflow"

echo
echo "=== LOCAL BUILD ==="

cd "$FRONTEND"

npm ci
VITE_WORKSPACE_API_URL="https://agent-traveler-dev2.onrender.com" npm run build

test -f dist/index.html
test -f dist/manifest.webmanifest
test -f dist/sw.js

echo "PASS production build"

cd "$ROOT"

echo
echo "=== GIT STATUS ==="

git status --short

echo
echo "=== STAGE ==="

git add frontend/vite.config.js
git add .github/workflows/deploy-pages.yml

echo
echo "=== COMMIT ==="

if git diff --cached --quiet; then
  echo "No GitHub Pages changes to commit."
else
  git commit -m "feat: deploy traveler dev frontend to github pages"
fi

echo
echo "=== PUSH ==="

git push origin main

echo
echo "=== REMOTE VERIFICATION ==="

LOCAL="$(git rev-parse HEAD)"
REMOTE="$(
  git ls-remote origin refs/heads/main |
  awk '{print $1}'
)"

if [ "$LOCAL" != "$REMOTE" ]; then
  echo "FAIL remote does not match local"
  echo "LOCAL : $LOCAL"
  echo "REMOTE: $REMOTE"
  exit 1
fi

echo "PASS GitHub remote matches local"

echo
echo "============================================================"
echo "TRAVELER DEV — GITHUB PAGES PUSH: PASS"
echo "============================================================"
echo
echo "Repository:"
echo "https://github.com/dolordprince/Agent-traveler-dev2"
echo
echo "Expected Pages URL:"
echo "https://dolordprince.github.io/Agent-traveler-dev2/"
echo
echo "Backend:"
echo "https://agent-traveler-dev2.onrender.com"
echo
echo "GitHub Pages workflow:"
echo ".github/workflows/deploy-pages.yml"
echo
echo "============================================================"
