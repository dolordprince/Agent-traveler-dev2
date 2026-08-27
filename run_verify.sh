#!/usr/bin/env bash
set -e

cd /root/Agent-traveler-dev2

echo "==> 1. Compiling Python files..."
python3 -m py_compile app/providers.py app/agent.py main.py

echo "==> 2. Verifying imports..."
./.venv/bin/python - <<'PY'
import app.providers as p
print("providers import: PASS")
print("chat export:", callable(getattr(p, "chat", None)))

import app.agent
print("agent import: PASS")
PY

echo "==> 3. Restarting main.py gateway..."
pkill -9 -f 'python.*main.py' || true
sleep 1

nohup ./.venv/bin/python main.py > gateway.log 2>&1 &

echo "==> Waiting for gateway startup..."
sleep 4

echo "==> Gateway Logs:"
tail -n 25 gateway.log

echo "==> 4. Testing /health endpoint..."
curl -sS --max-time 10 http://127.0.0.1:7860/health
echo ""

echo "==> 5. Testing real completion inference..."
curl -sS --max-time 60 \
  -X POST \
  http://127.0.0.1:7860/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{
    "model": "minimax/minimax-m3:free",
    "messages": [
      {
        "role": "user",
        "content": "Reply with exactly PASS"
      }
    ],
    "max_tokens": 20
  }'
echo ""

echo "==> 6. Scanning for exposed hard-coded secrets..."
grep -RInE 'sk-or-v1-|gsk_[A-Za-z0-9]+|csk-[A-Za-z0-9]+' app main.py --exclude-dir=__pycache__ || true

echo "==> Verification complete!"
