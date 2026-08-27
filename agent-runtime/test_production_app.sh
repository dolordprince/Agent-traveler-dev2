#!/usr/bin/env bash
set -e

WORKSPACE_DIR="/root/Agent-traveler-dev2/workspace"

echo "======================================================="
echo "==> 1. Preparing Clean Workspace Environment"
echo "======================================================="
rm -rf "$WORKSPACE_DIR"/*
rm -rf "$WORKSPACE_DIR"/.[!.]*
echo "Workspace cleared at $WORKSPACE_DIR"

echo ""
echo "======================================================="
echo "==> 2. Dispatching Full-Stack Production Application Task"
echo "======================================================="
echo "(This may take 1-3 minutes as the agent runs npm install, builds, and tests...)"

curl -sS \
  -X POST \
  http://127.0.0.1:8090/api/agent/run \
  -H 'content-type: application/json' \
  -d '{
    "maxSteps": 30,
    "prompt": "Build a production-ready Node.js REST API with Express and TypeScript for a Task Management service. Follow this precise execution flow:\n1. Inspect the empty workspace.\n2. Search and inspect the knowledge base for TypeScript/Express best practices if available.\n3. Create package.json, tsconfig.json, source files (src/app.ts, src/server.ts, src/tasks.ts), and test files.\n4. Install all required dependencies (express, typescript, ts-node, jest, supertest, @types/node, @types/express, @types/jest, @types/supertest) using npm install.\n5. Execute npm run build or npx tsc to type-check.\n6. Execute npx jest to run tests.\n7. If any build or test errors occur, inspect the stderr output, edit the code to fix the root cause, and rerun validation until it passes 100% cleanly."
  }' > agent_app_response.json

echo ""
echo "======================================================="
echo "==> 3. Agent Execution Summary"
echo "======================================================="
cat agent_app_response.json | grep -o '"steps":[0-9]*' || true
cat agent_app_response.json | grep -o '"toolCalls":[0-9]*' || true
cat agent_app_response.json | grep -o '"status":"[^"]*"' || true

echo ""
echo "======================================================="
echo "==> 4. Independent Filesystem Audit"
echo "======================================================="
echo "Generated Workspace Files (ignoring node_modules):"
find "$WORKSPACE_DIR" -maxdepth 3 -not -path '*/.*' -not -path '*/node_modules*'

echo ""
echo "======================================================="
echo "==> 5. Independent Build & Test Verification"
echo "======================================================="
cd "$WORKSPACE_DIR"

if [ -f "package.json" ]; then
  echo "--- Running independent TypeScript Compilation ---"
  npx tsc --noEmit || echo "TSC check returned errors."

  echo "--- Running independent Jest Test Suite ---"
  npx jest || echo "Test suite returned failures."
else
  echo "ERROR: package.json was not created by the agent!"
fi

echo ""
echo "======================================================="
echo "==> Production Acceptance Test Script Finished"
echo "======================================================="
