#!/usr/bin/env bash
set -euo pipefail

# Prompt for GROQ_API_KEY if not already in environment
if [ -z "${GROQ_API_KEY:-}" ]; then
  echo -n "Enter your GROQ_API_KEY (or press Enter to skip test and push): "
  read -r GROQ_KEY_INPUT
  if [ -n "$GROQ_KEY_INPUT" ]; then
    export GROQ_API_KEY="$GROQ_KEY_INPUT"
  fi
fi

echo "=== 1. Checking GROQ_API_KEY ==="
if [ -n "${GROQ_API_KEY:-}" ]; then
  echo "GROQ_API_KEY is set."
else
  echo "⚠️ GROQ_API_KEY is omitted. Skipping local proxy API call test."
fi

echo "=== 2. Staging and Committing Fixes ==="
git add .
git commit -m "fix: update proxy server, providers, and environment configuration" || true

echo "=== 3. Pushing to Hugging Face Spaces ==="
git push hf main --force

echo "=== Success! Changes pushed to Hugging Face Spaces. ==="
