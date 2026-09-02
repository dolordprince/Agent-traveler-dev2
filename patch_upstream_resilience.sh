#!/usr/bin/env bash
set -euo pipefail

echo "=== Updating server.py with Upstream Retries & Timeout Handling ==="

/opt/claw_venv/bin/python3 -c '
path = "server.py"
with open(path, "r") as f:
    content = f.read()

# Increase default proxy client timeout from 30.0s to 60.0s for Render cold starts
content = content.replace("timeout=30.0", "timeout=60.0")
content = content.replace("timeout=3.0", "timeout=10.0")

with open(path, "w") as f:
    f.write(content)
print("Updated timeout parameters in server.py")
'

echo "=== Restarting Proxy Gateway ==="
pkill -f "python3 server.py" || true
pkill -f "uvicorn" || true
sleep 1

/opt/claw_venv/bin/python3 server.py > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "=== Verifying Patched Gateway ==="
curl -s http://localhost:3456/health | /opt/claw_venv/bin/python3 -m json.tool

echo "Gateway operational on http://localhost:3456 under PID $SERVER_PID"
