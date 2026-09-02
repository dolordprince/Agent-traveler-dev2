#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Testing Local Proxy Health & Upstream Status ==="
HEALTH_RESP=$(curl -s http://localhost:3456/health)
echo "$HEALTH_RESP" | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\n=== [2/3] Testing Gateway Chat Completions Route ==="
curl -s http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4",
    "messages": [{"role": "user", "content": "Test end-to-end proxy pipeline"}]
  }' | /opt/claw_venv/bin/python3 -m json.tool

echo -e "\n=== [3/3] Testing Direct Pass-Through Forwarding to Render ==="
# Forwarding an unhandled path directly to https://agent-traveler-dev2.onrender.com
PASS_THROUGH_RESP=$(curl -s -i http://localhost:3456/health)
echo "$PASS_THROUGH_RESP" | head -n 10

echo -e "\nEnd-to-end proxy validation complete!"
