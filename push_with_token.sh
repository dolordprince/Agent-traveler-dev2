#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HF_TOKEN:-}" ]; then
  echo -n "Paste your Hugging Face Write Token (hf_...): "
  read -s HF_TOKEN_INPUT
  echo
  if [ -z "$HF_TOKEN_INPUT" ]; then
    echo "Error: Token cannot be empty."
    exit 1
  fi
  HF_TOKEN="$HF_TOKEN_INPUT"
fi

HF_REPO_URL="https://Daviddolor:${HF_TOKEN}@huggingface.co/spaces/Daviddolor/instatic-cms"

echo "=== 1. Updating Remote 'hf' with Token ==="
git remote set-url hf "$HF_REPO_URL"

echo "=== 2. Configuring Git Buffer & HTTP Settings ==="
git config http.postBuffer 524288000
git config http.sslVerify false || true

echo "=== 3. Pushing to Hugging Face Spaces ==="
git push hf main --force

echo "=== Successfully pushed to Hugging Face! ==="
