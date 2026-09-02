#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Adding Hugging Face README.md Metadata ==="
cat << 'READMEOF' > README.md
---
title: Traveler Dev
emoji: 🪐
colorFrom: indigo
colorTo: purple
sdk: static
pinned: false
---

# Traveler Dev Workspace
AI-powered workspace hosted on Hugging Face Spaces.
READMEOF

echo "=== 2. Committing and Pushing Config Fix ==="
git add README.md
git commit -m "fix: add Hugging Face space YAML configuration in README.md" || true
git push hf main --force

echo "=== Done! Check your live Space at https://huggingface.co/spaces/Daviddolor/instatic-cms ==="
