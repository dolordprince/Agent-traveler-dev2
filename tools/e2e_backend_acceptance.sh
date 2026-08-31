#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

request() {
  curl -sS --connect-timeout 10 --max-time 180 "$@"
}

assert_http() {
  local name="$1"
  shift

  local output
  local status

  set +e
  output=$(curl -sS --connect-timeout 10 --max-time 180 \
    -w $'\n__HTTP_STATUS__:%{http_code}' "$@" 2>&1)
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    fail "$name — curl exit $status"
    echo "$output"
    return 1
  fi

  local http
  http=$(printf '%s\n' "$output" | sed -n 's/^__HTTP_STATUS__://p')
  local body
  body=$(printf '%s\n' "$output" | sed '/^__HTTP_STATUS__:/d')

  echo "$body" | python -m json.tool >/dev/null 2>&1 || {
    echo "$body"
  }

  if [ "$http" = "200" ]; then
    pass "$name"
    return 0
  fi

  fail "$name — HTTP $http"
  echo "$body"
  return 1
}

echo
echo "============================================================"
echo " TRAVELER DEV BACKEND — PRODUCTION E2E ACCEPTANCE"
echo "============================================================"
echo "BASE_URL=$BASE_URL"
echo

echo "=== 1. PROCESS ==="

if [ -f traveler-dev.pid ]; then
  PID="$(cat traveler-dev.pid)"
  if kill -0 "$PID" 2>/dev/null; then
    pass "FastAPI process running PID=$PID"
  else
    fail "PID file exists but process is not running"
  fi
else
  fail "traveler-dev.pid missing"
fi

echo
echo "=== 2. PYTHON INTEGRITY ==="

if python -m py_compile \
  main.py \
  app/config.py \
  app/providers.py \
  app/agent.py \
  app/code_executor.py \
  app/llm_gateway.py; then
  pass "Python syntax"
else
  fail "Python syntax"
fi

echo
echo "=== 3. CORE API ==="

assert_http "GET /health" \
  "$BASE_URL/health" || true

assert_http "GET /api/health" \
  "$BASE_URL/api/health" || true

assert_http "GET /api/config" \
  "$BASE_URL/api/config" || true

assert_http "GET /api/provider/status" \
  "$BASE_URL/api/provider/status" || true

assert_http "GET /api/agent/capabilities" \
  "$BASE_URL/api/agent/capabilities" || true

assert_http "GET /api/webcontainer/status" \
  "$BASE_URL/api/webcontainer/status" || true

echo
echo "=== 4. PROVIDER CONFIGURATION ==="

HEALTH="$(request "$BASE_URL/health")"

printf '%s' "$HEALTH" | python - <<'PY'
import json
import sys

data = json.load(sys.stdin)

assert data.get("status") == "ok", data
assert data.get("service") == "traveler-dev-agent", data

credentials = data.get("credentials", {})

for provider in ("groq", "cerebras", "openrouter"):
    assert credentials.get(provider) is True, \
        f"{provider} credential unavailable: {credentials}"

print("Provider credentials: PASS")
PY

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
  pass "Required provider credentials exposed"
else
  fail "Required provider credentials exposed"
fi

echo
echo "=== 5. REAL GROQ INFERENCE ==="

GROQ_RESPONSE="$(request \
  -X POST "$BASE_URL/api/provider/run" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider":"groq",
    "model":"openai/gpt-oss-120b",
    "messages":[
      {
        "role":"user",
        "content":"Reply with exactly: TRAVELER_DEV_GROQ_E2E_PASS"
      }
    ]
  }' || true)"

echo "$GROQ_RESPONSE" | python -m json.tool 2>/dev/null || echo "$GROQ_RESPONSE"

if echo "$GROQ_RESPONSE" | grep -q "TRAVELER_DEV_GROQ_E2E_PASS"; then
  pass "Groq real inference"
else
  fail "Groq real inference"
fi

echo
echo "=== 6. REAL CEREBRAS INFERENCE ==="

CEREBRAS_RESPONSE="$(request \
  -X POST "$BASE_URL/api/provider/run" \
  -H 'Content-Type: application/json' \
  -d '{
    "provider":"cerebras",
    "messages":[
      {
        "role":"user",
        "content":"Reply with exactly: TRAVELER_DEV_CEREBRAS_E2E_PASS"
      }
    ]
  }' || true)"

echo "$CEREBRAS_RESPONSE" | python -m json.tool 2>/dev/null || echo "$CEREBRAS_RESPONSE"

if echo "$CEREBRAS_RESPONSE" | grep -q "TRAVELER_DEV_CEREBRAS_E2E_PASS"; then
  pass "Cerebras real inference"
else
  fail "Cerebras real inference"
fi

echo
echo "=== 7. OPENAI-COMPATIBLE CHAT ROUTE ==="

CHAT_RESPONSE="$(request \
  -X POST "$BASE_URL/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model":"openai/gpt-oss-120b",
    "messages":[
      {
        "role":"user",
        "content":"Reply with exactly: TRAVELER_DEV_CHAT_E2E_PASS"
      }
    ],
    "stream":false
  }' || true)"

echo "$CHAT_RESPONSE" | python -m json.tool 2>/dev/null || echo "$CHAT_RESPONSE"

if echo "$CHAT_RESPONSE" | grep -q "TRAVELER_DEV_CHAT_E2E_PASS"; then
  pass "/v1/chat/completions real inference"
else
  fail "/v1/chat/completions real inference"
fi

echo
echo "=== 8. AGENT EXECUTION ==="

AGENT_RESPONSE="$(request \
  -X POST "$BASE_URL/api/agent/run" \
  -H 'Content-Type: application/json' \
  -d '{
    "message":"Perform a backend smoke test. Do not modify files. Return exactly TRAVELER_DEV_AGENT_E2E_PASS when the request has been processed.",
    "stream":false
  }' || true)"

echo "$AGENT_RESPONSE" | python -m json.tool 2>/dev/null || echo "$AGENT_RESPONSE"

if echo "$AGENT_RESPONSE" | grep -q "TRAVELER_DEV_AGENT_E2E_PASS"; then
  pass "/api/agent/run real agent execution"
else
  fail "/api/agent/run real agent execution"
fi

echo
echo "=== 9. WEBContainer NETWORK TEST ==="

WC_URL="$(
  python - <<'PY'
from app.providers import WEBCONTAINER_API_URL
print(WEBCONTAINER_API_URL)
PY
)"

echo "Configured WebContainer URL: $WC_URL"

set +e
WC_OUTPUT="$(python - "$WC_URL" <<'PY'
import asyncio
import sys
import httpx

url = sys.argv[1]

async def main():
    try:
        async with httpx.AsyncClient(
            timeout=20,
            follow_redirects=True
        ) as client:
            response = await client.get(url)
            print(f"HTTP {response.status_code}")
            print(f"FINAL_URL {response.url}")
            return 0
    except Exception as exc:
        print(f"{type(exc).__name__}: {exc}")
        return 1

raise SystemExit(asyncio.run(main()))
PY
)"
WC_STATUS=$?
set -e

echo "$WC_OUTPUT"

if [ "$WC_STATUS" -eq 0 ]; then
  pass "WebContainer endpoint network connectivity"
else
  fail "WebContainer endpoint network connectivity"
fi

echo
echo "=== 10. WEBContainer FUNCTIONAL TEST ==="

WC_BOOT="$(request \
  -X POST "$BASE_URL/api/webcontainer/boot" \
  -H 'Content-Type: application/json' \
  -d '{
    "files":{
      "package.json":"{\"scripts\":{\"build\":\"echo build\"}}"
    }
  }' || true)"

echo "$WC_BOOT" | python -m json.tool 2>/dev/null || echo "$WC_BOOT"

if echo "$WC_BOOT" | grep -qiE '"instance_id"|"instanceId"|"id"'; then
  pass "WebContainer boot"
else
  fail "WebContainer boot"
fi

echo
echo "=== 11. ROUTE DISCOVERY ==="

ROUTES="$(python - <<'PY'
import main

for route in main.app.routes:
    methods = ",".join(sorted(route.methods or []))
    print(f"{methods:15} {route.path}")
PY
)"

echo "$ROUTES"

for route in \
  "/health" \
  "/api/health" \
  "/api/config" \
  "/api/provider/status" \
  "/api/agent/capabilities" \
  "/api/agent/run" \
  "/api/webcontainer/status" \
  "/api/webcontainer/boot" \
  "/api/webcontainer/exec"; do

  if echo "$ROUTES" | grep -q " $route$"; then
    pass "Route registered: $route"
  else
    fail "Route missing: $route"
  fi
done

echo
echo "=== 12. GIT WORKTREE ==="

git status --short

echo
echo "============================================================"
echo " RESULT"
echo "============================================================"
echo "PASS=$PASS"
echo "FAIL=$FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo
  echo "TRAVELER DEV BACKEND E2E: PASS"
  echo "SAFE TO PROCEED TO RENDER DEPLOYMENT."
  exit 0
else
  echo
  echo "TRAVELER DEV BACKEND E2E: FAIL"
  echo "DO NOT PUSH TO RENDER YET."
  exit 1
fi
