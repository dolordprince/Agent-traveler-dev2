#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

request() {
    curl -fsS \
        --connect-timeout 10 \
        --max-time 180 \
        "$@"
}

json_check() {
    python - "$@" <<'PY'
import json
import sys

raw = sys.stdin.read()
try:
    obj = json.loads(raw)
except Exception as exc:
    print(f"invalid JSON: {exc}")
    sys.exit(1)

print(json.dumps(obj, indent=2))
PY
}

echo
echo "============================================================"
echo " TRAVELER DEV AGENT BACKEND — PRODUCTION E2E TEST"
echo "============================================================"
echo "BASE_URL=$BASE_URL"
echo

echo "=== 1. ROOT ==="
if root="$(request "$BASE_URL/")"; then
    echo "$root" | python -m json.tool >/dev/null
    pass "Root endpoint"
else
    fail "Root endpoint"
fi

echo
echo "=== 2. HEALTH ==="
if health="$(request "$BASE_URL/health")"; then
    echo "$health" | python -m json.tool
    status="$(echo "$health" | python -c 'import json,sys; print(json.load(sys.stdin).get("status"))')"
    [[ "$status" == "ok" ]] && pass "Health status" || fail "Health status"
else
    fail "Health endpoint"
fi

echo
echo "=== 3. CAPABILITIES ==="
if caps="$(request "$BASE_URL/api/capabilities")"; then
    echo "$caps" | python -m json.tool
    pass "Capabilities endpoint"
else
    fail "Capabilities endpoint"
fi

echo
echo "=== 4. AGENT CAPABILITIES ==="
if acaps="$(request "$BASE_URL/api/agent/capabilities")"; then
    echo "$acaps" | python -m json.tool
    pass "Agent capabilities endpoint"
else
    fail "Agent capabilities endpoint"
fi

echo
echo "=== 5. MODEL DISCOVERY ==="
if models="$(request "$BASE_URL/v1/models")"; then
    echo "$models" | python -m json.tool

    python - "$models" <<'PY'
import json
import sys

data=json.loads(sys.argv[1])
items=data.get("data", [])
ids={x.get("id") for x in items}

required={"openai/gpt-oss-120b","openai/gpt-oss-20b"}

missing=required-ids

if missing:
    print("Missing models:", sorted(missing))
    sys.exit(1)

print("Required Groq models present:", sorted(required))
PY
    pass "Model discovery"
else
    fail "Model discovery"
fi

echo
echo "=== 6. REAL GROQ CHAT ==="
GROQ_RESPONSE="$(
request "$BASE_URL/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d '{
        "model":"openai/gpt-oss-120b",
        "messages":[
            {
                "role":"user",
                "content":"Reply exactly with: TRAVELER DEV GROQ E2E PASS"
            }
        ],
        "temperature":0
    }'
)" || true

if [[ -n "$GROQ_RESPONSE" ]]; then
    echo "$GROQ_RESPONSE" | python -m json.tool || true

    GROQ_CONTENT="$(
        echo "$GROQ_RESPONSE" |
        python -c '
import json,sys
d=json.load(sys.stdin)
print(d.get("choices",[{}])[0].get("message",{}).get("content",""))
'
    )"

    if [[ "$GROQ_CONTENT" == *"TRAVELER DEV GROQ E2E PASS"* ]]; then
        pass "Real Groq GPT-OSS 120B inference"
    else
        echo "Returned content: $GROQ_CONTENT"
        fail "Real Groq GPT-OSS 120B inference"
    fi
else
    fail "Real Groq GPT-OSS 120B inference"
fi

echo
echo "=== 7. STREAMING ==="
STREAM_OUTPUT="$(
curl -fsS \
    --connect-timeout 10 \
    --max-time 180 \
    -N \
    "$BASE_URL/api/chat/stream" \
    -H 'Content-Type: application/json' \
    -d '{
        "model":"openai/gpt-oss-120b",
        "messages":[
            {
                "role":"user",
                "content":"Reply exactly with: TRAVELER DEV STREAM E2E PASS"
            }
        ],
        "temperature":0
    }'
)" || true

if [[ "$STREAM_OUTPUT" == *"TRAVELER DEV STREAM E2E PASS"* ]]; then
    pass "Streaming inference"
else
    echo "$STREAM_OUTPUT" | head -100
    fail "Streaming inference"
fi

echo
echo "=== 8. AGENT RUN ==="
AGENT_RESPONSE="$(
request "$BASE_URL/api/agent/run" \
    -H 'Content-Type: application/json' \
    -d '{
        "messages":[
            {
                "role":"user",
                "content":"Reply exactly with: TRAVELER DEV AGENT E2E PASS"
            }
        ]
    }'
)" || true

if [[ -n "$AGENT_RESPONSE" ]]; then
    echo "$AGENT_RESPONSE" | python -m json.tool || true

    if echo "$AGENT_RESPONSE" | grep -q "TRAVELER DEV AGENT E2E PASS"; then
        pass "Agent execution"
    else
        fail "Agent execution"
    fi
else
    fail "Agent execution"
fi

echo
echo "=== 9. EXECUTE ENDPOINT ==="
EXEC_RESPONSE="$(
request "$BASE_URL/api/execute" \
    -H 'Content-Type: application/json' \
    -d '{
        "language":"python",
        "code":"print(\"TRAVELER DEV EXECUTE E2E PASS\")"
    }'
)" || true

if [[ -n "$EXEC_RESPONSE" ]]; then
    echo "$EXEC_RESPONSE" | python -m json.tool || true

    if echo "$EXEC_RESPONSE" | grep -q "TRAVELER DEV EXECUTE E2E PASS"; then
        pass "Code execution"
    else
        fail "Code execution"
    fi
else
    fail "Code execution"
fi

echo
echo "=== 10. WORKSPACES ==="
if workspace="$(request "$BASE_URL/api/workspaces")"; then
    echo "$workspace" | python -m json.tool
    pass "Workspace endpoint"
else
    fail "Workspace endpoint"
fi

echo
echo "=== 11. WEB CONTAINER STATUS ==="
if wc="$(request "$BASE_URL/api/webcontainer/status")"; then
    echo "$wc" | python -m json.tool

    enabled="$(
        echo "$wc" |
        python -c 'import json,sys; print(json.load(sys.stdin).get("enabled"))'
    )"

    if [[ "$enabled" == "True" ]]; then
        pass "WebContainer status endpoint"
    else
        fail "WebContainer status endpoint"
    fi
else
    fail "WebContainer status endpoint"
fi

echo
echo "=== 12. BUILD PIPELINE ==="
BUILD_RESPONSE="$(
request "$BASE_URL/api/build" \
    -H 'Content-Type: application/json' \
    -d '{
        "projectName":"traveler-dev-e2e",
        "prompt":"Create a production-ready single-page application that displays the text TRAVELER DEV BUILD E2E PASS. Use valid HTML, CSS and JavaScript."
    }'
)" || true

if [[ -n "$BUILD_RESPONSE" ]]; then
    echo "$BUILD_RESPONSE" | python -m json.tool || true

    JOB_ID="$(
        echo "$BUILD_RESPONSE" |
        python -c 'import json,sys; print(json.load(sys.stdin).get("jobId",""))'
    )"

    if [[ -n "$JOB_ID" ]]; then
        pass "Build job creation"

        echo
        echo "Waiting for build job: $JOB_ID"

        BUILD_DONE=0

        for i in $(seq 1 60); do
            STATUS="$(
                request "$BASE_URL/api/build/$JOB_ID/status" 2>/dev/null || true
            )"

            echo "$STATUS" | python -m json.tool 2>/dev/null || true

            PHASE="$(
                echo "$STATUS" |
                python -c 'import json,sys; print(json.load(sys.stdin).get("phase",""))' \
                2>/dev/null || true
            )"

            if [[ "$PHASE" == "done" ]]; then
                BUILD_DONE=1
                break
            fi

            if [[ "$PHASE" == "error" ]]; then
                break
            fi

            sleep 2
        done

        if [[ "$BUILD_DONE" == "1" ]]; then
            pass "Build pipeline completion"

            PREVIEW="$(
                request "$BASE_URL/api/build/$JOB_ID/preview" 2>/dev/null || true
            )"

            if [[ -n "$PREVIEW" ]]; then
                echo "$PREVIEW" | python -m json.tool || true
                pass "Build preview metadata"
            else
                fail "Build preview metadata"
            fi
        else
            fail "Build pipeline completion"
        fi
    else
        fail "Build job creation"
    fi
else
    fail "Build endpoint"
fi

echo
echo "=== 13. PYTHON COMPILE ==="
if python -m py_compile \
    main.py \
    app/providers.py \
    app/config.py \
    app/code_executor.py \
    app/llm_gateway.py
then
    pass "Python compilation"
else
    fail "Python compilation"
fi

echo
echo "=== RESULT ==="
echo "Failures: $FAILURES"

if [[ "$FAILURES" -eq 0 ]]; then
    echo
    echo "TRAVELER DEV BACKEND E2E: PASS"
    echo "Repository is ready for deployment validation."
    exit 0
else
    echo
    echo "TRAVELER DEV BACKEND E2E: FAIL"
    echo "Do NOT deploy to Render."
    exit 1
fi
