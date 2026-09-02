#!/usr/bin/env bash
set -euo pipefail

HF_REPO_URL="https://huggingface.co/spaces/Daviddolor/instatic-cms"

echo "=== 1. Configuring Hugging Face Remote ==="
if git remote | grep -q "^hf$"; then
  git remote set-url hf "$HF_REPO_URL"
else
  git remote add hf "$HF_REPO_URL"
fi

echo "=== 2. Pushing directly to Hugging Face Space ==="
git push hf main --force

echo "=== Done! The commit has been pushed directly to Hugging Face. ==="
