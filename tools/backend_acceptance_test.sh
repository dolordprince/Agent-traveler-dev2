#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PYTHON="$ROOT/.venv/bin/python"
PORT="${PORT:-7860}"
HOST="${HOST:-127.0.0.1}"

PASS=0
FAIL=0
SERVER_PID=""

pass() {
    printf '[ACCEPTANCE][PASS] %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf '[ACCEPTANCE][FAIL] %s\n' "$1"
    FAIL=$((FAIL + 1))
}

cleanup() {
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

echo "============================================================"
echo "TRAVELER DEV BACKEND ACCEPTANCE"
echo "============================================================"
echo "ROOT: $ROOT"
echo "PYTHON: $PYTHON"
echo

#
# 1. Required project files
#
for file in \
    main.py \
    requirements.txt \
    app/config.py \
    app/providers.py \
    app/agent.py \
    app/workspace.py \
    app/preview.py \
    app/artifacts.py \
    app/surge.py \
    app/knowledge.py \
    app/security.py
do
    if [[ -f "$ROOT/$file" ]]; then
        pass "$file"
    else
        fail "$file"
    fi
done

#
# 2. Python interpreter
#
if [[ -x "$PYTHON" ]]; then
    pass "Python virtual environment"
else
    fail "Python virtual environment"
    echo
    echo "ERROR: $PYTHON does not exist."
    exit 1
fi

#
# 3. Python syntax
#
if "$PYTHON" -m py_compile \
    "$ROOT/main.py" \
    "$ROOT"/app/*.py
then
    pass "Python syntax"
else
    fail "Python syntax"
fi

#
# 4. Required Python dependencies
#
if "$PYTHON" - <<'PY'
import importlib

required = [
    "fastapi",
    "uvicorn",
    "httpx",
    "pydantic",
]

missing = []

for module in required:
    try:
        importlib.import_module(module)
    except Exception as exc:
        missing.append(f"{module}: {exc}")

if missing:
    print("\n".join(missing))
    raise SystemExit(1)
PY
then
    pass "FastAPI/Uvicorn/httpx/Pydantic"
else
    fail "FastAPI/Uvicorn/httpx/Pydantic"
fi

#
# 5. Application imports
#
if "$PYTHON" - <<'PY'
import main
from app.agent import run_agent
from app.config import PRIMARY_MODEL, FALLBACK_MODELS
from app.providers import provider_status

assert callable(run_agent)
assert isinstance(PRIMARY_MODEL, str)
assert PRIMARY_MODEL
assert isinstance(FALLBACK_MODELS, list)
assert isinstance(provider_status(), dict)

print("application imports: OK")
PY
then
    pass "Application imports"
else
    fail "Application imports"
fi

#
# 6. Markdown knowledge
#
if [[ -d "$ROOT/knowledge" ]] && find "$ROOT/knowledge" -maxdepth 1 -type f -name '*.md' | grep -q .
then
    if "$PYTHON" - <<'PY'
from app.knowledge import load_knowledge

knowledge = load_knowledge()

if not isinstance(knowledge, str):
    raise SystemExit("knowledge loader did not return string")

print("knowledge characters:", len(knowledge))
PY
    then
        pass "Markdown knowledge"
    else
        fail "Markdown knowledge"
    fi
else
    fail "Markdown knowledge"
fi

#
# 7. Current production provider architecture
#
if "$PYTHON" - <<'PY'
from app.config import PRIMARY_MODEL, FALLBACK_MODELS

expected_primary = "groq/"
expected_fallback = "cerebras/"

if not PRIMARY_MODEL.startswith(expected_primary):
    raise SystemExit(
        f"PRIMARY_MODEL must use Groq; got {PRIMARY_MODEL!r}"
    )

if not any(
    model.startswith(expected_fallback)
    for model in FALLBACK_MODELS
):
    raise SystemExit(
        f"FALLBACK_MODELS must contain Cerebras; got {FALLBACK_MODELS!r}"
    )

# Explicitly reject the obsolete provider chain.
obsolete = (
    "x-ai/",
    "anthropic/",
    "google/",
)

bad = [
    model
    for model in [PRIMARY_MODEL, *FALLBACK_MODELS]
    if model.startswith(obsolete)
]

if bad:
    raise SystemExit(
        f"Obsolete providers detected in active chain: {bad!r}"
    )

print("primary:", PRIMARY_MODEL)
print("fallbacks:", FALLBACK_MODELS)
PY
then
    pass "Groq primary / Cerebras fallback configuration"
else
    fail "Groq primary / Cerebras fallback configuration"
fi

#
# 8. OpenRouter remains configured separately
#
if "$PYTHON" - <<'PY'
from app.config import OPENROUTER_URL

expected = "https://openrouter.ai/api/v1/chat/completions"

if OPENROUTER_URL != expected:
    raise SystemExit(
        f"Unexpected OpenRouter endpoint: {OPENROUTER_URL!r}"
    )

print("OpenRouter endpoint:", OPENROUTER_URL)
PY
then
    pass "OpenRouter configuration"
else
    fail "OpenRouter configuration"
fi

#
# 9. Provider status contract
#
if "$PYTHON" - <<'PY'
from app.providers import provider_status

status = provider_status()

required = {
    "primary",
    "fallbacks",
    "credentials",
    "openrouter",
}

missing = required.difference(status)

if missing:
    raise SystemExit(
        f"provider_status missing keys: {sorted(missing)}"
    )

credentials = status["credentials"]

if not isinstance(credentials, dict):
    raise SystemExit("credentials must be an object")

for provider in ("groq", "cerebras", "openrouter"):
    if provider not in credentials:
        raise SystemExit(
            f"credentials missing provider: {provider}"
        )

print(status)
PY
then
    pass "Provider status contract"
else
    fail "Provider status contract"
fi

#
# 10. Start an isolated acceptance server if one is not already healthy.
#
if curl -fsS --max-time 5 "http://${HOST}:${PORT}/health" >/tmp/traveler-health-existing.json 2>/dev/null
then
    pass "Live FastAPI health"
else
    echo "No healthy server detected on ${HOST}:${PORT}; starting acceptance server."

    "$PYTHON" -m uvicorn main:app \
        --host 0.0.0.0 \
        --port "$PORT" \
        >"$ROOT/logs/acceptance-uvicorn.log" 2>&1 &

    SERVER_PID=$!

    healthy=0

    for _ in $(seq 1 30); do
        if curl -fsS --max-time 3 \
            "http://${HOST}:${PORT}/health" \
            >/tmp/traveler-health.json 2>/dev/null
        then
            healthy=1
            break
        fi

        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            break
        fi

        sleep 1
    done

    if [[ "$healthy" == "1" ]]; then
        pass "Live FastAPI health"
    else
        fail "Live FastAPI health"

        echo
        echo "=== Uvicorn acceptance log ==="
        tail -n 100 "$ROOT/logs/acceptance-uvicorn.log" 2>/dev/null || true
    fi
fi

#
# 11. HTTP API contract
#
if curl -fsS --max-time 10 \
    "http://${HOST}:${PORT}/" \
    >/tmp/traveler-root.json
then
    if "$PYTHON" - <<'PY'
import json

with open("/tmp/traveler-root.json", encoding="utf-8") as f:
    data = json.load(f)

assert data.get("name") == "TRAVELER DEV"
assert data.get("status") == "operational"

print(data)
PY
    then
        pass "Root API contract"
    else
        fail "Root API contract"
    fi
else
    fail "Root API endpoint"
fi

if curl -fsS --max-time 10 \
    "http://${HOST}:${PORT}/api/health" \
    >/tmp/traveler-api-health.json
then
    pass "/api/health"
else
    fail "/api/health"
fi

if curl -fsS --max-time 10 \
    "http://${HOST}:${PORT}/api/config" \
    >/tmp/traveler-config.json
then
    if "$PYTHON" - <<'PY'
import json

with open("/tmp/traveler-config.json", encoding="utf-8") as f:
    data = json.load(f)

assert data.get("name") == "TRAVELER DEV"
assert data.get("preview_before_deployment") is True
assert "primary_model" in data
assert "fallback_models" in data

print(data)
PY
    then
        pass "/api/config"
    else
        fail "/api/config contract"
    fi
else
    fail "/api/config"
fi

if curl -fsS --max-time 10 \
    "http://${HOST}:${PORT}/api/providers" \
    >/tmp/traveler-providers.json
then
    pass "/api/providers"
else
    fail "/api/providers"
fi

#
# 12. Validate the live provider configuration returned by the API.
#
if "$PYTHON" - <<'PY'
import json

with open("/tmp/traveler-providers.json", encoding="utf-8") as f:
    data = json.load(f)

primary = data.get("primary", "")
fallbacks = data.get("fallbacks", [])

if not primary.startswith("groq/"):
    raise SystemExit(
        f"Live API primary is not Groq: {primary!r}"
    )

if not any(str(x).startswith("cerebras/") for x in fallbacks):
    raise SystemExit(
        f"Live API has no Cerebras fallback: {fallbacks!r}"
    )

print("live primary:", primary)
print("live fallbacks:", fallbacks)
PY
then
    pass "Live provider architecture"
else
    fail "Live provider architecture"
fi

#
# 13. Verify protected routes actually enforce authentication.
#
AUTH_STATUS="$(
    curl -sS \
        -o /tmp/traveler-auth-body.json \
        -w '%{http_code}' \
        --max-time 10 \
        -X POST \
        "http://${HOST}:${PORT}/api/agent/test" \
        -H 'Content-Type: application/json' \
        --data '{"job_id":"acceptance-invalid"}' \
        || true
)"

if [[ "$AUTH_STATUS" == "401" || "$AUTH_STATUS" == "403" || "$AUTH_STATUS" == "503" ]]; then
    pass "Protected API authentication"
else
    fail "Protected API authentication (HTTP $AUTH_STATUS)"
fi

echo
echo "============================================================"
echo "TRAVELER DEV BACKEND ACCEPTANCE"
echo "PASS=$PASS FAIL=$FAIL"
echo "============================================================"

if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi

echo "OVERALL: PASS"
