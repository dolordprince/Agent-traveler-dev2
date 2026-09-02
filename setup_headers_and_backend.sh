#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Writing Hugging Face Space README.md Configuration ==="
cat << 'READMEOF' > README.md
---
title: Traveler Dev Workspace
emoji: 🪐
colorFrom: indigo
colorTo: purple
sdk: static
pinned: false
header:
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Opener-Policy: same-origin
---
READMEOF

echo "=== 2. Creating Production Backend Server (server.js) ==="
cat << 'SERVEREOF' > server.js
import express from 'express';
import cors from 'cors';
import { exec } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';

const app = express();

// Apply required Cross-Origin Isolation Headers
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  next();
});

app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Surge Deployment Endpoint
app.post('/api/deploy-surge', async (req, res) => {
  const { files, domain } = req.body;

  if (!files || !domain) {
    return res.status(400).json({ error: 'Files and domain are required.' });
  }

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'surge-deploy-'));

  try {
    for (const [filePath, content] of Object.entries(files)) {
      const fullPath = path.join(tmpDir, filePath);
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
      fs.writeFileSync(fullPath, content, 'utf8');
    }

    const surgeToken = process.env.SURGE_TOKEN;
    const cmd = surgeToken 
      ? `npx surge ${tmpDir} ${domain} --token ${surgeToken}`
      : `npx surge ${tmpDir} ${domain}`;

    exec(cmd, (error, stdout, stderr) => {
      fs.rmSync(tmpDir, { recursive: true, force: true });

      if (error) {
        return res.status(500).json({ error: stderr || error.message });
      }

      return res.json({ 
        success: true, 
        url: `https://${domain}`,
        logs: stdout 
      });
    });
  } catch (err) {
    fs.rmSync(tmpDir, { recursive: true, force: true });
    return res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
SERVEREOF

echo "=== 3. Creating Cross-Origin Service Worker (coi-serviceworker.js) ==="
cat << 'SWEOF' > coi-serviceworker.js
if ("undefined" === typeof window) {
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener("fetch", (e) => {
    if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") return;
    e.respondWith(
      fetch(e.request).then((res) => {
        if (res.status === 0) return res;
        const h = new Headers(res.headers);
        h.set("Cross-Origin-Embedder-Policy", "require-corp");
        h.set("Cross-Origin-Opener-Policy", "same-origin");
        return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
      })
    );
  });
}
SWEOF

echo "=== Setup completed for Backend and Header Configs ==="
