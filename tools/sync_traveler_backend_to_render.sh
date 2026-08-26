#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/Agent-traveler-dev2"

cd "$ROOT"

echo "============================================================"
echo "TRAVELER DEV — PRODUCTION BACKEND SYNCHRONIZATION"
echo "============================================================"

echo
echo "[1/10] Repository"
git rev-parse --show-toplevel
git branch --show-current
git remote -v

echo
echo "[2/10] Validating Python"
.venv/bin/python -m py_compile main.py app/*.py
echo "[PASS] Python syntax"

echo
echo "[3/10] Validating application imports"
.venv/bin/python - <<'PY'
import main
from app.config import PRIMARY_MODEL, FALLBACK_MODELS
from app.providers import provider_status

print("main import: PASS")
print("primary:", PRIMARY_MODEL)
print("fallbacks:", FALLBACK_MODELS)
print("provider status:", provider_status())
PY

echo
echo "[4/10] Validating required production files"

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

for file in "${required[@]}"; do
    if [ ! -f "$file" ]; then
        echo "[FAIL] Missing: $file"
        exit 1
    fi

    echo "[PASS] $file"
done

echo
echo "[5/10] Removing Python bytecode from repository state"

find . \
    -type d \
    -name "__pycache__" \
    -prune \
    -exec rm -rf {} +

find . \
    -type f \
    \( -name "*.pyc" -o -name "*.pyo" \) \
    -delete

echo "[PASS] Generated Python bytecode removed"

echo
echo "[6/10] Git status before staging"
git status --short

echo
echo "[7/10] Staging complete backend"

git add \
    main.py \
    requirements.txt \
    Dockerfile \
    render.yaml \
    app/ \
    tools/

echo
echo "[8/10] Verifying staged production files"

git diff --cached --name-status

echo
echo "[9/10] Creating production commit"

if git diff --cached --quiet; then
    echo "[INFO] Nothing new to commit."
else
    git commit -m "deploy: production TRAVELER DEV backend"
fi

echo
echo "[10/10] Pushing production backend"

git push origin main

echo
echo "============================================================"
echo "PUSH COMPLETE"
echo "============================================================"

echo "COMMIT:"
git log -1 --oneline

echo
echo "TRACKED BACKEND:"
git ls-files \
    main.py \
    requirements.txt \
    Dockerfile \
    render.yaml \
    app/ \
    tools/

echo
echo "STATUS:"
git status --short

echo
echo "IMPORTANT:"
echo "Render must now rebuild from the pushed main branch."
echo "Do not change production API credentials yet."
