#!/usr/bin/env bash
set -euo pipefail

# Locate the index.html target
TARGET_HTML="index.html"
if [ -f "webcontainer-ui/index.html" ]; then
  TARGET_HTML="webcontainer-ui/index.html"
fi

BASE_DIR="$(dirname "$TARGET_HTML")"

echo "=== 1. Creating PWA Manifest and Service Worker ==="
cat << 'MANIFESTEOF' > "$BASE_DIR/manifest.json"
{
  "short_name": "TRAVELER",
  "name": "TRAVELER.DEV Workspace",
  "icons": [
    {
      "src": "https://cdn-icons-png.flaticon.com/512/1085/1085710.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "https://cdn-icons-png.flaticon.com/512/1085/1085710.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "start_url": ".",
  "background_color": "#050511",
  "theme_color": "#0b0d1b",
  "display": "standalone",
  "orientation": "portrait-primary"
}
MANIFESTEOF

cat << 'SWEOF' > "$BASE_DIR/sw.js"
const CACHE_NAME = 'traveler-dev-v1';

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(['./']))
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((res) => res || fetch(e.request))
  );
});
SWEOF

echo "=== 2. Overwriting UI with Integrated Layout in $TARGET_HTML ==="
cat << 'HTMLEOF' > "$TARGET_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TRAVELER.DEV - AI Workspace</title>
  <link rel="manifest" href="./manifest.json">
  <meta name="theme-color" content="#0b0d1b">
  <style>
    :root {
      --bg-dark: #070814;
      --bg-surface: #0b0d1b;
      --bg-card: #121528;
      --border: rgba(255, 255, 255, 0.08);
      --accent: #6366f1;
      --accent-gradient: linear-gradient(135deg, #6366f1, #a855f7);
      --text-main: #f1f5f9;
      --text-muted: #64748b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: 'Inter', system-ui, -apple-system, sans-serif;
      background: var(--bg-dark);
      color: var(--text-main);
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    
    /* TOP NAVBAR */
    .navbar {
      height: 50px;
      background: var(--bg-surface);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 16px;
    }
    .brand { font-weight: 800; font-size: 1rem; color: #a855f7; display: flex; align-items: center; gap: 8px; }
    .nav-actions { display: flex; gap: 10px; align-items: center; }
    .btn-nav {
      background: rgba(255,255,255,0.05);
      border: 1px solid var(--border);
      color: white;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
    }
    .btn-primary { background: var(--accent-gradient); border: none; font-weight: 600; }
    #pwa-install-btn { display: none; background: #22c55e; color: #000; font-weight: bold; border: none; }

    /* IDE MAIN LAYOUT */
    .ide-body {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* LEFT SIDEBAR */
    .icon-sidebar {
      width: 50px;
      background: #080915;
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 12px;
      gap: 16px;
    }
    .icon-btn { color: var(--text-muted); cursor: pointer; font-size: 18px; opacity: 0.7; }
    .icon-btn.active { color: var(--accent); opacity: 1; }

    /* FILE EXPLORER */
    .file-explorer {
      width: 220px;
      background: var(--bg-surface);
      border-right: 1px solid var(--border);
      padding: 12px;
      font-size: 13px;
    }
    .tree-item { padding: 4px 8px; border-radius: 4px; cursor: pointer; color: #cbd5e1; }
    .tree-item:hover { background: rgba(255,255,255,0.05); }
    .tree-item.active { background: rgba(99, 102, 241, 0.15); color: #818cf8; }

    /* CENTER EDITOR & BOTTOM DOCK */
    .editor-container {
      flex: 2;
      display: flex;
      flex-direction: column;
      background: #05060e;
      border-right: 1px solid var(--border);
    }
    .tabs-bar {
      height: 38px;
      background: var(--bg-surface);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
    }
    .tab {
      padding: 0 16px;
      height: 100%;
      display: flex;
      align-items: center;
      border-right: 1px solid var(--border);
      font-size: 12px;
      color: var(--text-muted);
      cursor: pointer;
    }
    .tab.active { background: #05060e; color: #f1f5f9; border-top: 2px solid var(--accent); }
    .code-area {
      flex: 1;
      padding: 16px;
      font-family: 'Fira Code', monospace;
      font-size: 13px;
      color: #38bdf8;
      overflow-y: auto;
    }

    /* BOTTOM AI PROMPT DOCK */
    .prompt-dock {
      background: var(--bg-surface);
      border-top: 1px solid var(--border);
      padding: 12px 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .prompt-input-wrapper {
      display: flex;
      background: #13162b;
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 6px 12px;
    }
    .prompt-input-wrapper input {
      flex: 1;
      background: transparent;
      border: none;
      color: white;
      outline: none;
      font-size: 13px;
    }
    .quick-tags { display: flex; gap: 8px; }
    .tag { background: rgba(255,255,255,0.04); border: 1px solid var(--border); font-size: 11px; padding: 4px 8px; border-radius: 4px; color: var(--text-muted); cursor: pointer; }

    /* RIGHT PREVIEW / WORKSPACE PANEL */
    .preview-container {
      flex: 1.2;
      display: flex;
      flex-direction: column;
      background: var(--bg-surface);
    }
    .preview-header {
      height: 38px;
      padding: 0 12px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 12px;
    }
    iframe { flex: 1; border: none; background: white; }
  </style>
</head>
<body>

  <div class="navbar">
    <div class="brand">🪐 TRAVELER.DEV <span style="font-size:10px; color:#22c55e; background:rgba(34,197,94,0.1); padding:2px 6px; border-radius:10px;">• Online</span></div>
    <div class="nav-actions">
      <button id="pwa-install-btn" class="btn-nav">📲 Install App</button>
      <button class="btn-nav">🔑 API Keys</button>
      <button class="btn-nav btn-primary">🚀 Deploy</button>
    </div>
  </div>

  <div class="ide-body">
    <div class="icon-sidebar">
      <div class="icon-btn active">📁</div>
      <div class="icon-btn">🤖</div>
      <div class="icon-btn">⌨️</div>
      <div class="icon-btn">⚙️</div>
    </div>

    <div class="file-explorer">
      <div style="font-weight:700; color:var(--text-muted); margin-bottom:12px; font-size:11px;">EXPLORER</div>
      <div class="tree-item">📁 src</div>
      <div class="tree-item" style="padding-left: 20px;">📁 components</div>
      <div class="tree-item active" style="padding-left: 20px;">📄 App.tsx</div>
      <div class="tree-item" style="padding-left: 20px;">📄 index.tsx</div>
      <div class="tree-item">📄 package.json</div>
      <div class="tree-item">📄 vite.config.ts</div>
    </div>

    <div class="editor-container">
      <div class="tabs-bar">
        <div class="tab active">App.tsx</div>
        <div class="tab">index.tsx</div>
        <div class="tab">styles.css</div>
      </div>
      <div class="code-area">
        <pre>import React from 'react';<br>import { BrowserRouter } from 'react-router-dom';<br><br>export default function App() {<br>  return (&lt;div&gt;Welcome to Traveler.dev Workspace&lt;/div&gt;);<br>}</pre>
      </div>

      <div class="prompt-dock">
        <div class="quick-tags">
          <div class="tag">✨ Build a website</div>
          <div class="tag">⚡ Create an app</div>
          <div class="tag">🔧 Fix errors</div>
        </div>
        <div class="prompt-input-wrapper">
          <input type="text" id="prompt" placeholder="Describe what you want to build..." />
          <button id="build-btn" class="btn-nav btn-primary">Generate</button>
        </div>
      </div>
    </div>

    <div class="preview-container">
      <div class="preview-header">
        <span>👁️ Live Preview</span>
        <button class="btn-nav" id="reload-btn">Reload</button>
      </div>
      <iframe id="preview-iframe" src="about:blank"></iframe>
    </div>
  </div>

  <script type="module" src="./src/main.js"></script>
  
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('./sw.js').catch(err => console.log('SW reg failed:', err));
      });
    }

    let deferredPrompt;
    const installBtn = document.getElementById('pwa-install-btn');
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredPrompt = e;
      installBtn.style.display = 'inline-block';
    });

    installBtn.addEventListener('click', () => {
      installBtn.style.display = 'none';
      if (deferredPrompt) {
        deferredPrompt.prompt();
        deferredPrompt.userChoice.then(() => { deferredPrompt = null; });
      }
    });
  </script>
</body>
</html>
HTMLEOF

echo "=== 3. Pushing changes to Hugging Face ==="
git add .
git commit -m "feat(ui): adopt full IDE layout with bottom prompt dock and PWA support" || true

# Push to Hugging Face remote
git push hf main --force || git push origin main --force

echo "=== Success! Full layout updated and PWA configured. ==="
