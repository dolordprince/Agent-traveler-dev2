#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/4] Installing Missing Dependencies (httpx) ==="
/opt/claw_venv/bin/pip install --quiet httpx

echo "=== [2/4] Killing Stale Server Processes ==="
pkill -f "python3 server.py" || true
pkill -f "uvicorn" || true
sleep 1

echo "=== [3/4] Launching Proxy Gateway ==="
/opt/claw_venv/bin/python3 server.py > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for port 3456..."
sleep 3

echo "=== [4/4] Verifying Endpoints ==="
echo "1. Health check:"
curl -s http://localhost:3456/health | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\n2. Chat Completion:"
curl -s http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4",
    "messages": [{"role": "user", "content": "Build e-commerce site"}]
  }' | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\nServer running under PID: $SERVER_PID"
