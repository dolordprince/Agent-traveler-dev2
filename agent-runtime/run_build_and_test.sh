#!/usr/bin/env bash
set -e

cd /root/Agent-traveler-dev2/agent-runtime

echo "==> 1. Compiling TypeScript..."
npm run build

echo "==> 2. Verifying Node server runtime..."
pkill -9 -f 'node.*dist/server.js' || true
sleep 1

node dist/server.js > runtime.log 2>&1 &
echo "==> Waiting for Node runtime to start..."
sleep 3

cat runtime.log

echo "==> 3. Testing GET /health..."
curl -sS http://127.0.0.1:8090/health
echo ""

echo "==> 4. Executing Real End-to-End Coding-Agent Inference..."
curl -sS \
  -X POST \
  http://127.0.0.1:8090/api/agent/run \
  -H 'content-type: application/json' \
  -d '{
    "prompt": "Reply with exactly PASS"
  }'
echo ""

echo "==> 5. Auditing TypeScript source for exposed hardcoded API keys..."
grep -RInE 'sk-or-v1-|gsk_[A-Za-z0-9]+|csk-[A-Za-z0-9]+' src dist --exclude-dir=node_modules || true

echo "==> Repairs & verifications complete!"
