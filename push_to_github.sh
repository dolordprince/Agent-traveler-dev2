#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Checking Git Repository Status ==="
git status

echo -e "\n=== [2/3] Staging Gateway Deployment Files ==="
git add server.py requirements.txt render.yaml Dockerfile setup_proxy_gateway.sh

echo "Staged changes:"
git status --short

echo -e "\n=== [3/3] Committing & Pushing to GitHub ==="
git commit -m "feat: add reverse proxy gateway and Render configuration" || echo "No changes to commit."

# Detect active remote branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
echo "Pushing to remote branch '$CURRENT_BRANCH'..."

git push origin "$CURRENT_BRANCH"

echo -e "\nSuccessfully pushed deployment files to GitHub!"
