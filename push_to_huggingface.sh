#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Checking Git Status ==="
git status

echo "=== 2. Adding Hugging Face Remote ==="
HF_REPO_URL="https://huggingface.co/spaces/Daviddolor/instatic-cms"

if git remote | grep -q "^hf$"; then
  echo "Remote 'hf' already exists. Updating URL..."
  git remote set-url hf "$HF_REPO_URL"
else
  echo "Adding new remote 'hf'..."
  git remote add hf "$HF_REPO_URL"
fi

echo "=== 3. Staging and Committing Any Uncommitted Changes ==="
git add .
git commit -m "feat: apply dark theme and update workspace header UI" || true

echo "=== 4. Pushing to Hugging Face Spaces ==="
git push hf main --force

echo "=== Pushed successfully! Check status at https://huggingface.co/spaces/Daviddolor/instatic-cms ==="
