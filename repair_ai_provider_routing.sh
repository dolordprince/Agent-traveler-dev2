#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/Agent-traveler-dev2"
ENV_FILE="$ROOT/.env"
BACKUP="$ROOT/.env.backup.$(date +%Y%m%d-%H%M%S)"

cd "$ROOT"

echo "============================================================"
echo "TRAVELER DEV — AI PROVIDER ROUTING REPAIR"
echo "============================================================"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[FAIL] Missing $ENV_FILE"
  exit 1
fi

cp "$ENV_FILE" "$BACKUP"
echo "[PASS] Environment backup: $BACKUP"

set -a
source "$ENV_FILE"
set +a

mask() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf '%s' "<EMPTY>"
  elif (( ${#value} <= 10 )); then
    printf '%s' '********'
  else
    printf '%s...%s' "${value:0:6}" "${value: -4}"
  fi
}

echo
echo "=== CREDENTIAL STATE ==="

echo "OPENROUTER_API_KEY : $(mask "${OPENROUTER_API_KEY:-}")"
echo "AI_GATEWAY_API_KEY : $(mask "${AI_GATEWAY_API_KEY:-}")"
echo "ANTHROPIC_API_KEY  : $(mask "${ANTHROPIC_API_KEY:-}")"

echo
echo "=== VALIDATING CREDENTIAL FORMATS ==="

if [[ "${OPENROUTER_API_KEY:-}" == http* ]]; then
  echo "[FAIL] OPENROUTER_API_KEY contains a URL."
  echo "       It must contain the actual OpenRouter API key."
  exit 1
fi

if [[ "${AI_GATEWAY_API_KEY:-}" == *"vercel ai-gateway"* ]]; then
  echo "[FAIL] AI_GATEWAY_API_KEY contains descriptive text instead of a credential."
  exit 1
fi

if [[ "${OPENROUTER_API_KEY:-}" != sk-or-v1-* ]]; then
  echo "[WARN] OPENROUTER_API_KEY does not have the expected OpenRouter key prefix."
fi

if [[ -z "${AI_GATEWAY_API_KEY:-}" ]]; then
  echo "[FAIL] AI_GATEWAY_API_KEY is empty."
  exit 1
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "[FAIL] OPENROUTER_API_KEY is empty."
  exit 1
fi

echo "[PASS] Credential variables are structurally valid."

echo
echo "=== PROVIDER ENDPOINTS ==="

export OPENROUTER_BASE_URL="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
export AI_GATEWAY_BASE_URL="${AI_GATEWAY_BASE_URL:-https://ai-gateway.vercel.sh/v1}"

echo "OpenRouter : $OPENROUTER_BASE_URL"
echo "AI Gateway : $AI_GATEWAY_BASE_URL"

echo
echo "=== TESTING OPENROUTER AUTHENTICATION ==="

OPENROUTER_RESPONSE="$(curl -sS \
  --max-time 30 \
  -w $'\nHTTP_STATUS:%{http_code}' \
  "$OPENROUTER_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -H "HTTP-Referer: https://traveler.dev" \
  -H "X-Title: TRAVELER DEV" \
  --data '{
    "model":"openrouter/free",
    "messages":[
      {
        "role":"user",
        "content":"Reply with exactly TRAVELER_DEV_OPENROUTER_OK"
      }
    ],
    "max_tokens":32
  }' || true)"

echo "$OPENROUTER_RESPONSE"

OPENROUTER_STATUS="$(printf '%s\n' "$OPENROUTER_RESPONSE" | sed -n 's/^HTTP_STATUS://p' | tail -1)"

if [[ "$OPENROUTER_STATUS" == "200" ]]; then
  echo "[PASS] OpenRouter authentication and inference."
else
  echo "[FAIL] OpenRouter inference HTTP $OPENROUTER_STATUS."
  echo
  echo "Replace OPENROUTER_API_KEY with a real OpenRouter API key."
  exit 1
fi

echo
echo "=== TESTING VERCEL AI GATEWAY ==="

GATEWAY_RESPONSE="$(curl -sS \
  --max-time 45 \
  -w $'\nHTTP_STATUS:%{http_code}' \
  "$AI_GATEWAY_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $AI_GATEWAY_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "model":"anthropic/claude-opus-5",
    "messages":[
      {
        "role":"user",
        "content":"Reply with exactly TRAVELER_DEV_AI_GATEWAY_OK"
      }
    ],
    "max_tokens":32
  }' || true)"

echo "$GATEWAY_RESPONSE"

GATEWAY_STATUS="$(printf '%s\n' "$GATEWAY_RESPONSE" | sed -n 's/^HTTP_STATUS://p' | tail -1)"

if [[ "$GATEWAY_STATUS" == "200" ]]; then
  echo "[PASS] Vercel AI Gateway authentication and inference."
else
  echo "[FAIL] Vercel AI Gateway inference HTTP $GATEWAY_STATUS."
  exit 1
fi

echo
echo "============================================================"
echo "PROVIDER VALIDATION PASSED"
echo "============================================================"

echo
echo "Restarting TRAVELER DEV services..."

bash "$ROOT/start-all.sh"

sleep 4

echo
echo "Running complete verification..."

bash "$ROOT/verify.sh"

echo
echo "============================================================"
echo "AI PROVIDER REPAIR COMPLETE"
echo "============================================================"
