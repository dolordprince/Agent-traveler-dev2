#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

export TRAVELER_GATEWAY_URL="${TRAVELER_GATEWAY_URL:-https://agent-traveler-dev2.onrender.com}"
export TRAVELER_AGENT_MODEL="${TRAVELER_AGENT_MODEL:-anthropic/claude-sonnet-4}"

if [ -z "${GATEWAY_API_KEY:-}" ]; then
  echo "[FAIL] GATEWAY_API_KEY is not configured."
  echo "Configure it in the deployment environment."
  exit 1
fi

exec node server.mjs
