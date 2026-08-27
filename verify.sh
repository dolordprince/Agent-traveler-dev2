#!/usr/bin/env bash
PROJECT="/root/Agent-traveler-dev2"
RUNTIME="$PROJECT/agent-runtime"
PASS=0; FAIL=0

ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1 — $2"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo "TRAVELER DEV — FULL VERIFICATION"
echo "============================================================"

check() {
  local label="$1" url="$2" expect="$3"
  result=$(curl -s --max-time 5 "$url" 2>/dev/null || true)
  if echo "$result" | grep -q "$expect" 2>/dev/null; then
    ok "$label"
  else
    fail "$label" "${result:0:120}"
  fi
}

check "Gateway health"        "http://127.0.0.1:7860/health"   "ok"
check "Browser bridge health" "http://127.0.0.1:8091/health"   "ok"
check "Runtime health"        "http://127.0.0.1:8090/health"   "ok"
check "Runtime api/health"    "http://127.0.0.1:8090/api/health" "ok"
check "Runtime config"        "http://127.0.0.1:8090/api/config" "available"

echo ""
echo "Testing gateway inference..."
INFER=$(curl -s --max-time 30 -X POST http://127.0.0.1:7860/v1/chat/completions \
  -H "content-type: application/json" \
  -d '{"model":"minimax/minimax-m3:free","messages":[{"role":"user","content":"say PASS"}],"max_tokens":10}' 2>/dev/null || true)
if echo "$INFER" | grep -q "choices"; then
  ok "Gateway inference"
else
  fail "Gateway inference" "${INFER:0:120}"
fi

echo ""
echo "Testing browser tool execution..."
AGENT=$(curl -s --max-time 60 -X POST http://127.0.0.1:8090/api/agent/run \
  -H "content-type: application/json" \
  -d '{"prompt":"Use browser_navigate to go to https://example.com and return the page title.","maxSteps":5}' 2>/dev/null || true)
TC=$(echo "$AGENT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('toolCalls',0))" 2>/dev/null || echo 0)
if [ "$TC" -gt 0 ]; then
  ok "Agent browser tool execution (toolCalls: $TC)"
else
  fail "Agent browser tool execution" "toolCalls=0 | ${AGENT:0:120}"
fi

echo ""
echo "Testing TypeScript build..."
cd "$RUNTIME"
if npm run build >/dev/null 2>&1; then
  ok "TypeScript build"
else
  fail "TypeScript build" "see npm run build output"
fi

echo ""
echo "============================================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
