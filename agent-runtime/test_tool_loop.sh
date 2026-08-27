#!/usr/bin/env bash
set -e

WORKSPACE_DIR="/root/Agent-traveler-dev2/workspace"
mkdir -p "$WORKSPACE_DIR"

echo "==> 1. Setting up clean workspace file..."
cat << 'FILE_EOF' > "$WORKSPACE_DIR/math_utils.py"
def add(a, b):
    return a + b
FILE_EOF

echo "==> 2. Sending prompt requiring multi-step tool execution..."
curl -sS \
  -X POST \
  http://127.0.0.1:8090/api/agent/run \
  -H 'content-type: application/json' \
  -d '{
    "prompt": "Inspect the workspace for python files. Search the knowledge base for testing standards if available, add a multiply(a, b) function to math_utils.py, create a test file test_math.py, and run python3 -m unittest test_math.py to verify it works."
  }' > agent_response.json

echo ""
echo "==> 3. Response Summary:"
cat agent_response.json | grep -o '"steps":[0-9]*' || true
cat agent_response.json | grep -o '"toolCalls":[0-9]*' || true

echo ""
echo "==> 4. Checking Workspace Artifacts:"
echo "--- math_utils.py ---"
cat "$WORKSPACE_DIR/math_utils.py" || true
echo ""
echo "--- test_math.py ---"
cat "$WORKSPACE_DIR/test_math.py" || true

echo ""
echo "==> Verification complete!"
