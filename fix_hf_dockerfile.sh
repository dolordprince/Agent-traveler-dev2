#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Updating README.md for Docker SDK (Port 7860) ==="
cat << 'READMEOF' > README.md
---
title: Traveler Dev Workspace
emoji: 🪐
colorFrom: indigo
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
---

# Traveler Dev Workspace
AI-powered workspace hosted on Hugging Face Spaces.
READMEOF

echo "=== 2. Creating Multi-stage Production Dockerfile ==="
cat << 'DOCKEREOF' > Dockerfile
# Step 1: Build the static frontend app
FROM node:22-alpine AS builder

WORKDIR /app

# Check if webcontainer-ui subfolder exists, otherwise build from root
COPY . .

RUN if [ -d "webcontainer-ui" ]; then \
      cd webcontainer-ui && npm install && npm run build && cp -r dist /app/dist; \
    else \
      npm install && npm run build; \
    fi

# Step 2: Serve the built static files on port 7860 using serve
FROM node:22-alpine

WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/dist /app/dist

EXPOSE 7860

CMD ["serve", "-s", "dist", "-l", "7860"]
DOCKEREOF

echo "=== 3. Committing and Pushing to Hugging Face ==="
git add README.md Dockerfile
git commit -m "fix: update Dockerfile to build subfolder and serve production bundle on 7860" || true
git push hf main --force

echo "=== Done! Hugging Face Space is now rebuilding cleanly. ==="
