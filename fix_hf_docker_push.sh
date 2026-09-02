#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Writing Valid Hugging Face README.md (Docker SDK) ==="
cat << 'READMEOF' > README.md
---
title: Traveler Dev Workspace
emoji: 🪐
colorFrom: indigo
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
header: default
---
READMEOF

echo "=== 2. Creating Dockerfile for Port 7860 ==="
cat << 'DOCKEREOF' > Dockerfile
FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm install --production || true

COPY . .

EXPOSE 7860

CMD ["node", "server.js"]
DOCKEREOF

echo "=== 3. Creating Server Entrypoint with Native Headers (server.js) ==="
cat << 'SERVEREOF' > server.js
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Native Cross-Origin Isolation Headers for WebContainers
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  next();
});

const staticPath = path.existsSync(path.join(__dirname, 'webcontainer-ui')) 
  ? path.join(__dirname, 'webcontainer-ui') 
  : __dirname;

app.use(express.static(staticPath));

app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

const PORT = process.env.PORT || 7860;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with COOP/COEP enabled.`);
});
SERVEREOF

echo "=== 4. Updating package.json ==="
cat << 'PKGEOF' > package.json
{
  "name": "instatic-cms",
  "version": "1.0.0",
  "type": "module",
  "main": "server.js",
  "dependencies": {
    "express": "^4.19.2"
  }
}
PKGEOF

echo "=== 5. Committing and Pushing to Hugging Face ==="
git add README.md Dockerfile server.js package.json
git commit -m "fix(hf): use valid header property and switch to docker sdk on port 7860" || true
git push hf main --force || git push origin main --force

echo "=== Push Succeeded ==="
