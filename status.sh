#!/usr/bin/env bash
# TRAVELER DEV — Check all service health
echo "============================================================"
echo "TRAVELER DEV — SERVICE STATUS"
echo "============================================================"

check() {
  local name="$1" url="$2"
  result=$(curl -s --max-time 3 "$url" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$result" ]; then
    echo "[UP]  $name"
    echo "      $result" | python3 -c "import sys,json; d=json.load(sys.stdin); print('     ', {k:v for k,v in d.items() if k in ['status','service','model','openrouter']})" 2>/dev/null || true
  else
    echo "[DOWN] $name ($url)"
  fi
}

check "Python Gateway   " "http://127.0.0.1:7860/health"
check "Browser Bridge   " "http://127.0.0.1:8091/health"
check "Agent Runtime    " "http://127.0.0.1:8090/health"
echo ""

echo "Processes:"
ps aux | grep -E "main\.py|browser_tool_bridge|dist/server" | grep -v grep | awk '{print " ", $1, $2, $11, $12}' || echo "  none"
