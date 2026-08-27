#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/Agent-traveler-dev2"
cd "$ROOT"

echo "============================================================"
echo "TRAVELER DEV — AGENT KNOWLEDGE WORKFLOW VERIFICATION"
echo "============================================================"

fail() {
  echo "[FAIL] $1"
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -d knowledge ]] || fail "knowledge directory missing"
find knowledge -maxdepth 1 -type f -name '*.md' | grep -q . \
  || fail "No Markdown knowledge documents found"

pass "Markdown knowledge documents exist"

python3 - <<'PY'
from app.knowledge import (
    list_knowledge,
    search_knowledge,
    load_knowledge,
)

items = list_knowledge()

if not items:
    raise SystemExit(
        "Knowledge loader returned no documents"
    )

print("Knowledge documents:", len(items))

full = load_knowledge()

if not full.strip():
    raise SystemExit(
        "Knowledge loader returned empty content"
    )

print("Knowledge characters:", len(full))

result = search_knowledge(
    "AI SDK tools agents"
)

print("Knowledge search results:", len(result))

if not result:
    raise SystemExit(
        "Knowledge search returned no result"
    )

print(
    "Top result:",
    result[0]["name"]
)
PY

pass "Python knowledge loader/search operational"

[[ -f agent-runtime/src/tools.ts ]] \
  || fail "TypeScript tools missing"

grep -q "searchKnowledge" \
  agent-runtime/src/tools.ts \
  || fail "searchKnowledge tool missing"

grep -q "readKnowledge" \
  agent-runtime/src/tools.ts \
  || fail "readKnowledge tool missing"

grep -q "listKnowledge" \
  agent-runtime/src/tools.ts \
  || fail "listKnowledge tool missing"

pass "TypeScript knowledge tools registered"

grep -q "searchKnowledge" \
  agent-runtime/src/agent.ts \
  || fail "Agent does not expose knowledge search"

grep -q "readKnowledge" \
  agent-runtime/src/agent.ts \
  || fail "Agent does not expose knowledge reader"

grep -q "runCommand" \
  agent-runtime/src/agent.ts \
  || fail "Agent does not expose command execution"

pass "Autonomous agent has knowledge + workspace tools"

grep -q "Surge" \
  agent-runtime/src/agent.ts \
  || fail "Surge deployment policy missing"

if grep -q "deployment.*Vercel" \
  agent-runtime/src/agent.ts; then
  fail "Agent still identifies Vercel as deployment target"
fi

pass "Deployment policy points to Surge"

if command -v npm >/dev/null 2>&1; then
  cd agent-runtime

  npm install

  npm run build

  pass "Agent runtime TypeScript build"
fi

cd "$ROOT"

python3 -m compileall -q app

pass "Backend Python compilation"

echo
echo "============================================================"
echo "KNOWLEDGE WORKFLOW VERIFICATION PASS"
echo "============================================================"
