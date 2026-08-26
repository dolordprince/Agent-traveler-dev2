#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/Agent-traveler-dev2"
cd "$ROOT"

log()  { printf '[SYNC] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

echo "============================================================"
echo "TRAVELER DEV — PRODUCTION BACKEND SYNCHRONIZATION"
echo "============================================================"

[ -d "$ROOT/.git" ] || fail "Not a Git repository: $ROOT"

log "Repository: $ROOT"
log "Branch: $(git branch --show-current)"
log "Remote: $(git remote get-url origin)"

[ "$(git branch --show-current)" = "main" ] || fail "Expected main branch"

echo
echo "[1/10] Checking working tree"
git status --short
echo

echo "[2/10] Checking required local files"

required=(
  "main.py"
  "requirements.txt"
  "Dockerfile"
  "render.yaml"
  "app/__init__.py"
  "app/config.py"
  "app/providers.py"
  "app/agent.py"
  "app/workspace.py"
  "app/preview.py"
  "app/artifacts.py"
  "app/surge.py"
  "app/knowledge.py"
  "app/security.py"
)

# app/__init__.py is required as an explicit production package marker.
if [ ! -f "app/__init__.py" ]; then
    mkdir -p app
    : > app/__init__.py
    log "Created missing app/__init__.py"
fi

for file in "${required[@]}"; do
    [ -f "$file" ] || fail "Missing local production file: $file"
    pass "$file"
done

echo
echo "[3/10] Validating Python syntax"

"$ROOT/.venv/bin/python" -m compileall -q main.py app \
    || fail "Python syntax validation failed"

pass "Python syntax"

echo
echo "[4/10] Validating application imports"

"$ROOT/.venv/bin/python" - <<'PY'
import main
from app.agent import run_agent
from app.config import PRIMARY_MODEL, FALLBACK_MODELS
from app.providers import provider_status

print("main import: PASS")
print("primary:", PRIMARY_MODEL)
print("fallbacks:", FALLBACK_MODELS)
print("provider status:", provider_status())
PY

pass "Application imports"

echo
echo "[5/10] Checking Git ignore rules"

for file in "${required[@]}"; do
    ignored="$(git check-ignore -v "$file" 2>/dev/null || true)"

    if [ -n "$ignored" ]; then
        echo "[WARN] Git ignore rule affects: $file"
        echo "$ignored"
    fi
done

echo
echo "[6/10] Staging complete production backend"

# Explicitly stage the application tree.
git add main.py
git add requirements.txt
git add Dockerfile
git add render.yaml
git add app/

# Fail if any required file is still absent from the index.
for file in "${required[@]}"; do
    git ls-files --error-unmatch "$file" >/dev/null 2>&1 \
        || fail "Required file was not staged/tracked: $file"
done

pass "All required backend files are tracked"

echo
echo "[7/10] Verifying staged backend"

echo "--- TRACKED BACKEND FILES ---"
git ls-files | grep -E '^(main.py|app/|Dockerfile|render.yaml|requirements.txt)$|^app/' | sort

echo
echo "--- REQUIRED FILE CHECK ---"

for file in "${required[@]}"; do
    git ls-files --error-unmatch "$file" >/dev/null 2>&1 \
        || fail "Git index missing: $file"
    pass "$file"
done

echo
echo "[8/10] Inspecting staged changes"

git diff --cached --stat

echo
git diff --cached --name-status

echo
echo "[9/10] Creating production synchronization commit"

if git diff --cached --quiet; then
    log "No new Git changes detected."
else
    git commit -m "fix: synchronize production backend application" \
        || fail "Git commit failed"
fi

echo
echo "[10/10] Pushing production backend to GitHub"

git push origin main \
    || fail "Git push failed"

echo
echo "============================================================"
echo "POST-PUSH VERIFICATION"
echo "============================================================"

git fetch origin main

LOCAL_COMMIT="$(git rev-parse main)"
REMOTE_COMMIT="$(git rev-parse origin/main)"

echo "LOCAL : $LOCAL_COMMIT"
echo "REMOTE: $REMOTE_COMMIT"

[ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ] \
    || fail "Local main and origin/main do not match"

pass "GitHub main synchronized"

echo
echo "--- REMOTE TRACKED BACKEND FILES ---"

git ls-tree -r --name-only origin/main \
    | grep -E '^(main.py|app/|Dockerfile|render.yaml|requirements.txt)$|^app/' \
    | sort

echo
echo "--- REMOTE REQUIRED FILE CHECK ---"

for file in "${required[@]}"; do
    git cat-file -e "origin/main:$file" \
        || fail "Remote GitHub tree is missing: $file"
    pass "origin/main:$file"
done

echo
echo "============================================================"
echo "SYNCHRONIZATION RESULT"
echo "============================================================"
echo "PASS: Production backend is synchronized to origin/main."
echo "PASS: app/ is tracked."
echo "PASS: app/__init__.py is tracked."
echo "PASS: Required backend modules are tracked."
echo "PASS: Render Docker build source is synchronized."
echo
echo "IMPORTANT:"
echo "Do NOT export GROQ_API_KEY, CEREBRAS_API_KEY, or"
echo "OPENROUTER_API_KEY into this shell."
echo "Render environment credentials remain managed by Render."
echo
echo "NEXT: trigger/redeploy the Render service, then run:"
echo
echo 'RENDER_URL="https://agent-traveler-dev2.onrender.com" bash tools/verify_render_production.sh'
echo "============================================================"
