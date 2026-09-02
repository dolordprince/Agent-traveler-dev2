#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Forcefully Terminating Existing Processes ==="
pkill -9 -f "server.py" || true
pkill -9 -f "uvicorn" || true
sleep 2

# Verify port 3456 is free
if command -v fuser &> /dev/null; then
  fuser -k 3456/tcp || true
fi

echo "=== [2/3] Starting Proxy Gateway Server ==="
/opt/claw_venv/bin/python3 server.py > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for port 3456 to bind..."
sleep 4

echo "=== [3/3] Verifying Gateway Health ==="
HEALTH_RESP=$(curl -s http://localhost:3456/health)

if [ -z "$HEALTH_RESP" ]; then
  echo "ERROR: Server output is empty. Displaying server.log:"
  cat server.log
  exit 1
fi

echo "$HEALTH_RESP" | /opt/claw_venv/bin/python3 -m json.tool
echo "Proxy active on http://localhost:3456 under PID $SERVER_PID."
