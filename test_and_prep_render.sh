#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Testing End-to-End Chat Completion ==="
COMPLETION_OUT=$(curl -s http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4",
    "messages": [{"role": "user", "content": "Build e-commerce dashboard"}]
  }')

echo "$COMPLETION_OUT" | /opt/claw_venv/bin/python3 -m json.tool

# Extract generated App ID to verify local filesystem write
APP_ID=$(echo "$COMPLETION_OUT" | /opt/claw_venv/bin/python3 -c "import sys, json; print(json.load(sys.stdin)['choices'][0]['message']['content'].split('App ID: ')[1].split('\n')[0])" 2>/dev/null || echo "")

if [ -n "$APP_ID" ]; then
  echo -e "\nVerifying local workspace creation for $APP_ID:"
  ls -la "/tmp/claw_workspaces/$APP_ID"
fi

echo -e "\n=== [2/3] Testing Upstream Reverse Proxy Forwarding ==="
# Test forwarding an unhandled route to upstream backend
UPSTREAM_OUT=$(curl -s http://localhost:3456/random-pass-through-route)
echo "Upstream Fallback Response: $UPSTREAM_OUT"

echo -e "\n=== [3/3] Generating Render Deployment Artifacts ==="

# 1. Generate requirements.txt
cat << 'REQEOF' > requirements.txt
fastapi>=0.100.0
uvicorn>=0.22.0
httpx>=0.24.0
pydantic>=2.0.0
REQEOF
echo "Created requirements.txt"

# 2. Generate render.yaml
cat << 'RENDEREEOF' > render.yaml
services:
  - type: web
    name: openclaw-proxy-gateway
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn server:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: TARGET_BACKEND_URL
        value: https://agent-traveler-dev2.onrender.com
      - key: WORKSPACE_BASE
        value: /tmp/claw_workspaces
RENDEREEOF
echo "Created render.yaml"

# 3. Generate Dockerfile (Optional containerized strategy)
cat << 'DOCKEREOF' > Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install Node.js for skill executions
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3456

ENV PORT=3456
ENV TARGET_BACKEND_URL=https://agent-traveler-dev2.onrender.com
ENV WORKSPACE_BASE=/tmp/claw_workspaces

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "3456"]
DOCKEREOF
echo "Created Dockerfile"

echo -e "\n======================================================="
echo "ALL TESTS & ARTIFACTS COMPLETE!"
echo "To finish deployment to Render:"
echo "1. Commit files: git add server.py requirements.txt render.yaml Dockerfile && git commit -m 'Add Proxy Gateway'"
echo "2. Push to GitHub repository: git push origin main"
echo "3. Connect repo on Render Dashboard (https://dashboard.render.com)"
echo "======================================================="
