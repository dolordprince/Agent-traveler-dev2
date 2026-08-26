#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${RENDER_URL:-https://agent-traveler-dev2.onrender.com}"
BASE_URL="${BASE_URL%/}"

echo "============================================================"
echo "TRAVELER DEV — RENDER DEPLOYMENT MISMATCH DIAGNOSTIC"
echo "============================================================"
echo "Render URL: $BASE_URL"
echo

echo "=== LOCAL GIT ==="
git branch --show-current || true
git rev-parse HEAD || true
git remote -v || true
echo

echo "=== LOCAL FILES ==="
printf '%s\n' \
    main.py \
    requirements.txt \
    app/config.py \
    app/providers.py \
    app/agent.py \
    app/security.py \
    render.yaml \
    Dockerfile

for file in main.py requirements.txt app/config.py app/providers.py app/agent.py app/security.py render.yaml Dockerfile; do
    if [ -f "$file" ]; then
        printf '[LOCAL][PASS] %s exists\n' "$file"
    else
        printf '[LOCAL][FAIL] %s missing\n' "$file"
    fi
done
echo

echo "=== LOCAL VERSION / PROVIDER CONTRACT ==="
.venv/bin/python - <<'PY'
from app.config import PRIMARY_MODEL, FALLBACK_MODELS
from app.providers import provider_status
import main

print("main import: PASS")
print("primary:", PRIMARY_MODEL)
print("fallbacks:", FALLBACK_MODELS)
print("provider_status:", provider_status())
PY
echo

echo "=== LIVE RENDER ROUTES ==="

check_route() {
    local path="$1"

    echo
    echo "--- GET $path ---"

    curl \
        --silent \
        --show-error \
        --max-time 30 \
        -D /tmp/traveler_headers \
        -o /tmp/traveler_body \
        "$BASE_URL$path" || true

    printf 'HTTP: '
    awk 'toupper($1) ~ /^HTTP/ {code=$2} END {print code}' /tmp/traveler_headers

    echo "BODY:"
    head -c 5000 /tmp/traveler_body
    echo
}

check_route "/health"
check_route "/"
check_route "/api/health"
check_route "/api/config"
check_route "/api/providers"
check_route "/docs"
check_route "/openapi.json"

echo
echo "============================================================"
echo "DIAGNOSIS"
echo "============================================================"

health="$(curl -fsS --max-time 30 "$BASE_URL/health" 2>/dev/null || true)"

if printf '%s' "$health" | grep -q '"gateway":"OpenAI Compatible"'; then
    echo "[DIAGNOSIS] Render is serving the OpenAI-compatible gateway application."
    echo "[DIAGNOSIS] It does NOT match the locally validated TRAVELER DEV backend contract."
fi

if curl -sS --max-time 30 -o /dev/null -w '%{http_code}' \
    "$BASE_URL/api/config" | grep -q '^404$'; then
    echo "[DIAGNOSIS] /api/config is absent from the deployed application."
fi

echo
echo "LOCAL COMMIT:"
git rev-parse HEAD

echo
echo "IMPORTANT:"
echo "Do not modify provider credentials yet."
echo "Do not export GROQ_API_KEY, CEREBRAS_API_KEY, or OPENROUTER_API_KEY."
echo "The deployment target must first be made identical to the validated backend."
