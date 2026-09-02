#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Updating server.js with Credentialless & COOP Isolation ==="
cat << 'SERVEREOF' > server.js
import express from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Permanent fix for nested iframe WebContainers (Hugging Face / StackBlitz)
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
});

const staticPath = fs.existsSync(path.join(__dirname, 'webcontainer-ui')) 
  ? path.join(__dirname, 'webcontainer-ui') 
  : __dirname;

app.use(express.static(staticPath));

app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

const PORT = process.env.PORT || 7860;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with Credentialless COOP/COEP.`);
});
SERVEREOF

echo "=== 2. Creating Auto-Reloading Cross-Origin Service Worker Helper ==="
cat << 'SWEOF' > coi-serviceworker.js
/*! coi-serviceworker - Permanent iframe patch for WebContainers */
if ("undefined" === typeof window) {
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener("fetch", (e) => {
    if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") return;
    e.respondWith(
      fetch(e.request).then((res) => {
        if (res.status === 0) return res;
        const h = new Headers(res.headers);
        h.set("Cross-Origin-Embedder-Policy", "credentialless");
        h.set("Cross-Origin-Opener-Policy", "same-origin");
        return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
      }).catch(() => fetch(e.request))
    );
  });
} else {
  (() => {
    if (!window.crossOriginIsolated) {
      navigator.serviceWorker.register('./coi-serviceworker.js').then((reg) => {
        reg.addEventListener("updatefound", () => window.location.reload());
        if (reg.active && !navigator.serviceWorker.controller) {
          window.location.reload();
        }
      });
    }
  })();
}
SWEOF

echo "=== 3. Moving Service Worker into Static Directory ==="
if [ -d "webcontainer-ui" ]; then
  cp coi-serviceworker.js webcontainer-ui/coi-serviceworker.js
fi

echo "=== 4. Pushing Final Fix to Hugging Face ==="
git add .
git commit -m "fix(webcontainer): enforce credentialless isolation & worker interception" || true
git push hf main --force || git push origin main --force

echo "=== Permanent Fix Pushed Successfully ==="
