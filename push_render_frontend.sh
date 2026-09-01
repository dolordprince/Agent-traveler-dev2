#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "============================================================"
echo "TRAVELER DEV — PUSH FRONTEND TO GITHUB"
echo "============================================================"

cd "$ROOT"

BRANCH="$(git branch --show-current)"

if [ "$BRANCH" != "main" ]; then
  echo "FAIL expected main branch, got: $BRANCH"
  exit 1
fi

echo
echo "=== VERIFY FRONTEND ==="

test -f frontend/package.json
test -f frontend/package-lock.json
test -f frontend/index.html
test -f frontend/vite.config.js
test -f frontend/src/main.js
test -f frontend/src/stackblitz.js
test -f frontend/src/project-files.js
test -f frontend/src/workspace-api.js
test -f frontend/public/manifest.webmanifest
test -f frontend/public/sw.js

echo "PASS frontend source"

echo
echo "=== VERIFY BUILD ==="

cd frontend
npm run build

test -f dist/index.html
test -f dist/manifest.webmanifest
test -f dist/sw.js

echo "PASS production build"

cd "$ROOT"

echo
echo "=== GIT STATUS ==="
git status --short

echo
echo "=== STAGE FRONTEND CONFIGURATION ==="

git add frontend

if git diff --cached --quiet; then
  echo "No frontend changes detected."
else
  git commit -m "feat: connect traveler dev frontend to render backend"
fi

echo
echo "=== PUSH MAIN ==="

git push origin main

echo
echo "=== VERIFY REMOTE ==="

LOCAL="$(git rev-parse HEAD)"

REMOTE="$(
  git ls-remote origin refs/heads/main |
  awk '{print $1}'
)"

if [ -z "$REMOTE" ]; then
  echo "FAIL remote main not found"
  exit 1
fi

if [ "$LOCAL" != "$REMOTE" ]; then
  echo "FAIL local and remote commits differ"
  echo "LOCAL : $LOCAL"
  echo "REMOTE: $REMOTE"
  exit 1
fi

echo "PASS remote matches local"

echo
echo "=== FINAL COMMIT ==="
git log -1 --format='%H%n%s'

echo
echo "============================================================"
echo "TRAVELER DEV — FRONTEND PUSH: PASS"
echo "============================================================"
echo "Repository: dolordprince/Agent-traveler-dev2"
echo "Branch:     main"
echo "Frontend:   frontend/"
echo "Backend:    https://agent-traveler-dev2.onrender.com"
echo "============================================================"
