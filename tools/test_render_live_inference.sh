#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${RENDER_URL:-https://agent-traveler-dev2.onrender.com}"
BASE_URL="${BASE_URL%/}"

if [ -z "${GATEWAY_API_KEY:-}" ]; then
    echo "[ERROR] GATEWAY_API_KEY is not available in this local shell."
    echo
    echo "This test intentionally does NOT require GROQ_API_KEY,"
    echo "CEREBRAS_API_KEY, or OPENROUTER_API_KEY locally."
    echo
    echo "Supply only the gateway authentication key if your API requires it:"
    echo '  GATEWAY_API_KEY="your-gateway-key" bash tools/test_render_live_inference.sh'
    exit 2
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "============================================================"
echo "TRAVELER DEV — LIVE RENDER INFERENCE TEST"
echo "============================================================"
echo "URL: $BASE_URL"
echo

HTTP_CODE="$(
    curl \
        --silent \
        --show-error \
        --max-time 180 \
        -o "$TMP" \
        -w '%{http_code}' \
        -X POST "$BASE_URL/v1/chat/completions" \
        -H "Authorization: Bearer ${GATEWAY_API_KEY}" \
        -H "Content-Type: application/json" \
        --data @- <<'JSON'
{
  "messages": [
    {
      "role": "system",
      "content": "You are TRAVELER DEV production inference verification."
    },
    {
      "role": "user",
      "content": "Reply with exactly: TRAVELER_DEV_LIVE_INFERENCE_OK"
    }
  ],
  "temperature": 0,
  "max_tokens": 32
}
JSON
)"

echo "HTTP STATUS: $HTTP_CODE"
cat "$TMP"
echo
echo

if [ "$HTTP_CODE" != "200" ]; then
    echo "[INFERENCE][FAIL] Production inference returned HTTP $HTTP_CODE"
    exit 1
fi

if ! grep -q "TRAVELER_DEV_LIVE_INFERENCE_OK" "$TMP"; then
    echo "[INFERENCE][FAIL] Expected model response was not returned."
    exit 1
fi

echo "[INFERENCE][PASS] Real production LLM inference succeeded."
echo "[INFERENCE][PASS] Render environment credentials are usable."
echo "OVERALL: PASS"
