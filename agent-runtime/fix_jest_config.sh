#!/usr/bin/env bash
set -e

WORKSPACE_DIR="/root/Agent-traveler-dev2/workspace"

# 1. Provide standard jest configuration in workspace
mkdir -p "$WORKSPACE_DIR"
cat << 'JEST_EOF' > "$WORKSPACE_DIR/jest.config.json"
{
  "preset": "ts-jest",
  "testEnvironment": "node",
  "roots": ["<rootDir>/src", "<rootDir>/tests"],
  "testMatch": [
    "**/tests/**/*.ts",
    "**/?(*.)+(spec|test).ts"
  ],
  "transform": {
    "^.+\\.tsx?$": "ts-jest"
  }
}
JEST_EOF

echo "==> Updated workspace jest.config.json to match all test files in tests/"

# 2. Update agent system instruction to ensure it places tests matching jest conventions
sed -i 's/\*\*\/\\\?(\*\.)+(spec|test)\.ts/\*\*\/\*\.ts/g' src/agent.ts || true

npm run build

echo "==> Re-running Production Acceptance Test..."
cd /root/Agent-traveler-dev2/agent-runtime
./test_production_app.sh
