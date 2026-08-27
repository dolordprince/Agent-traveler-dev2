#!/usr/bin/env bash
# TRAVELER DEV — Start all services
set -euo pipefail

PROJECT="/root/Agent-traveler-dev2"
RUNTIME="$PROJECT/agent-runtime"

echo "============================================================"
echo "TRAVELER DEV — STARTING ALL SERVICES"
echo "============================================================"

# ── 1. Load environment ──────────────────────────────────────────
if [ -f "$PROJECT/.env" ]; then
  set -a && source "$PROJECT/.env" && set +a
  echo "[PASS] .env loaded"
fi

# ── 2. Start Python gateway on 7860 ─────────────────────────────
pkill -f "python.*main.py" 2>/dev/null || true
sleep 1
cd "$PROJECT"
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
nohup bash /root/Agent-traveler-dev2/run_gateway.sh > gateway.log 2>nohup ./.venv/bin/python main.py > gateway.log 2>&11 &
GATEWAY_PID=$!
echo "Gateway PID: $GATEWAY_PID"

for i in {1..20}; do
  if curl -s http://127.0.0.1:7860/health >/dev/null 2>&1; then
    echo "[PASS] Gateway online (7860)"
    break
  fi
  sleep 1
done

# ── 3. Start browser bridge on 8091 ─────────────────────────────
cd "$RUNTIME"
pkill -f "browser_tool_bridge.py" 2>/dev/null || true
sleep 1
nohup python3 browser_tool_bridge.py > browser_bridge.log 2>&1 &
BRIDGE_PID=$!
echo "$BRIDGE_PID" > browser_bridge.pid
sleep 4

if curl -s http://127.0.0.1:8091/health >/dev/null 2>&1; then
  echo "[PASS] Browser bridge online (8091)"
else
  echo "[FAIL] Browser bridge failed:"
  cat browser_bridge.log
  exit 1
fi

# ── 4. Start Node agent runtime on 8090 ─────────────────────────
pkill -f "node.*dist/server.js" 2>/dev/null || true
sleep 1
export TRAVELER_BROWSER_BRIDGE_URL="http://127.0.0.1:8091"
nohup node dist/server.js > runtime.log 2>&1 &
RUNTIME_PID=$!
echo "$RUNTIME_PID" > runtime.pid
sleep 3

if curl -s http://127.0.0.1:8090/health >/dev/null 2>&1; then
  echo "[PASS] Agent runtime online (8090)"
else
  echo "[FAIL] Runtime failed:"
  cat runtime.log
  exit 1
fi

echo ""
echo "============================================================"
echo "ALL SERVICES RUNNING"
echo "============================================================"
echo "Gateway      : http://127.0.0.1:7860"
echo "Browser bridge: http://127.0.0.1:8091"
echo "Agent runtime : http://127.0.0.1:8090"
echo ""
echo "Logs:"
echo "  Gateway      : $PROJECT/gateway.log"
echo "  Browser bridge: $RUNTIME/browser_bridge.log"
echo "  Runtime      : $RUNTIME/runtime.log"
