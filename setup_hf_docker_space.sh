#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Updating README.md YAML Header for Docker SDK ==="
cat << 'READMEOF' > README.md
---
title: Traveler Dev Workspace
emoji: 🪐
colorFrom: indigo
colorTo: purple
sdk: docker
app_port: 5173
pinned: false
---

# Traveler Dev Workspace
AI-powered workspace hosted on Hugging Face Spaces.
READMEOF

echo "=== 2. Creating Dockerfile ==="
cat << 'DOCKEREOF' > Dockerfile
FROM node:22-alpine

WORKDIR /app

# Copy root configurations
COPY package*.json ./

# Copy source directory (adjust path if your React app is inside a folder)
COPY . .

# Install dependencies and build static assets
RUN npm ci || npm install

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]
DOCKEREOF

echo "=== 3. Committing and Pushing Docker Configuration ==="
git add README.md Dockerfile
git commit -m "fix: convert HF space to Docker SDK to build and serve workspace UI" || true
git push hf main --force

echo "=== Success! Hugging Face is now building your workspace container. ==="
