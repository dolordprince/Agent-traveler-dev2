#!/usr/bin/env bash
# TRAVELER DEV — Stop all services
echo "Stopping all TRAVELER DEV services..."
pkill -f "python.*main.py" 2>/dev/null && echo "[STOP] Gateway" || true
pkill -f "browser_tool_bridge.py" 2>/dev/null && echo "[STOP] Browser bridge" || true
pkill -f "node.*dist/server.js" 2>/dev/null && echo "[STOP] Agent runtime" || true
sleep 1
echo "Done."
