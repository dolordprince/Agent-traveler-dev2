#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/5] Checking Previous Execution Logs ==="
if [ -f server.log ]; then
  echo "--- Contents of server.log ---"
  cat server.log
  echo "------------------------------"
else
  echo "No server.log found."
fi

echo "=== [2/5] Ensuring Node.js & npx Availability ==="
if ! command -v npx &> /dev/null; then
  echo "npx not found. Installing Node.js and npm via apt..."
  apt-get update -qq && apt-get install -y -qq nodejs npm
fi
echo "Node version: $(node -v)"
echo "NPX version: $(npx -v)"

echo "=== [3/5] Setting up Isolated Virtual Environment ==="
pkill -f "python3 server.py" || true
pkill -f "uvicorn" || true

rm -rf /opt/claw_venv
python3 -m venv /opt/claw_venv
/opt/claw_venv/bin/pip install --upgrade pip --quiet
/opt/claw_venv/bin/pip install --quiet fastapi uvicorn pydantic

echo "=== [4/5] Launching Production Gateway in Background ==="
/opt/claw_venv/bin/python3 server.py > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting 5 seconds for server initialization..."
sleep 5

echo "=== [5/5] Running Live Endpoint Verification ==="

echo "Testing /health:"
HEALTH_RESP=$(curl -s http://localhost:3456/health)
echo "$HEALTH_RESP" | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\nTesting /v1/models:"
MODELS_RESP=$(curl -s http://localhost:3456/v1/models)
echo "$MODELS_RESP" | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\nTesting /v1/chat/completions:"
COMPLETION_RESP=$(curl -s http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4",
    "messages": [{"role": "user", "content": "Build a simple admin portal"}]
  }')
echo "$COMPLETION_RESP" | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\nDeployment active. Server PID: $SERVER_PID. Monitoring logs at server.log."
