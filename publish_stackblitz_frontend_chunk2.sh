#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRONTEND="$ROOT/frontend"

echo "============================================================"
echo "TRAVELER DEV — PUBLISH FRONTEND + STACKBLITZ BRIDGE"
echo "============================================================"

cd "$ROOT"

echo
echo "=== FINAL BUILD ==="

cd "$FRONTEND"
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
echo "=== STAGED FRONTEND ==="

git add frontend

echo
echo "=== COMMIT ==="

if git diff --cached --quiet; then
  echo "No new frontend changes to commit."
else
  git commit -m "feat: production traveler dev stackblitz workspace frontend"
fi

echo
echo "=== PUSH ==="

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
  echo "FAIL unable to determine git branch"
  exit 1
fi

git push origin "$BRANCH"

echo
echo "=== REMOTE VERIFICATION ==="

LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git ls-remote origin "refs/heads/$BRANCH" | awk '{print $1}')"

if [ -z "$REMOTE" ]; then
  echo "FAIL remote branch not found"
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
echo "=== FINAL ==="
git log -1 --oneline

echo
echo "============================================================"
echo "TRAVELER DEV FRONTEND PUBLISHED: PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "Branch:   $BRANCH"
echo "Commit:   $LOCAL"
echo
echo "The frontend is ready for the Render/frontend deployment step."
echo "============================================================"
