#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/4] Stopping Stale Server Instances ==="
pkill -f "python3 server.py" || true
pkill -f "uvicorn" || true
sleep 1

echo "=== [2/4] Checking Previous Failure Log ==="
if [ -f server.log ]; then
  echo "--- Tail of server.log ---"
  tail -n 20 server.log
  echo "--------------------------"
fi

echo "=== [3/4] Launching Server Process ==="
/opt/claw_venv/bin/python3 server.py > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for port 3456 to open..."
for i in {1..10}; do
  if curl -s http://localhost:3456/health > /dev/null 2>&1; then
    echo "Server successfully bound to port 3456! (PID: $SERVER_PID)"
    break
  fi
  sleep 1
done

echo "=== [4/4] Verifying Health Endpoint ==="
HEALTH_OUTPUT=$(curl -s http://localhost:3456/health)

if [ -z "$HEALTH_OUTPUT" ]; then
  echo "ERROR: Server output is empty. Check server.log:"
  cat server.log
  exit 1
else
  echo "$HEALTH_OUTPUT" | /opt/claw_venv/bin/python3 -m json.tool
fi
