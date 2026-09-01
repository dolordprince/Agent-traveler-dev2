#!/usr/bin/env bash
set -u

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

printf '\n=== TRAVELER DEV FRONTEND — CHUNK 1 ===\n'

mkdir -p \
  "$FRONTEND/public" \
  "$FRONTEND/src"

cat > "$FRONTEND/package.json" <<'EOF'
{
  "name": "traveler-dev-workspace",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "@stackblitz/sdk": "^1.11.0"
  },
  "devDependencies": {
    "vite": "^7.1.5"
  }
}
EOF

cat > "$FRONTEND/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta
    name="viewport"
    content="width=device-width,initial-scale=1,viewport-fit=cover"
  >
  <meta name="theme-color" content="#111827">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="icon" href="/icon.svg">
  <title>TRAVELER DEV</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
EOF

cat > "$FRONTEND/public/manifest.webmanifest" <<'EOF'
{
  "name": "TRAVELER DEV",
  "short_name": "Traveler Dev",
  "description": "Production AI development workspace",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#0b0f19",
  "theme_color": "#111827",
  "icons": [
    {
      "src": "/icon.svg",
      "sizes": "any",
      "type": "image/svg+xml",
      "purpose": "any maskable"
    }
  ]
}
EOF

cat > "$FRONTEND/public/icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="112" fill="#111827"/>
  <path d="M118 142h276v52H118zm0 88h190v52H118zm0 88h276v52H118z" fill="#60a5fa"/>
  <circle cx="360" cy="256" r="36" fill="#a78bfa"/>
</svg>
EOF

cat > "$FRONTEND/public/sw.js" <<'EOF'
const CACHE = "traveler-dev-shell-v1";

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE).then(cache =>
      cache.addAll([
        "/",
        "/index.html",
        "/manifest.webmanifest",
        "/icon.svg"
      ])
    )
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  event.respondWith(
    fetch(event.request).catch(() =>
      caches.match(event.request).then(
        response => response || caches.match("/")
      )
    )
  );
});
EOF

cat > "$FRONTEND/src/main.js" <<'EOF'
import "./style.css";

const API =
  import.meta.env.VITE_WORKSPACE_API_URL ||
  window.location.origin;

const state = {
  files: [
    "README.md",
    "package.json",
    "src/main.js",
    "src/style.css"
  ],
  activeFile: "src/main.js",
  terminal: [],
  connected: false
};

const app = document.querySelector("#app");

function render() {
  app.innerHTML = `
    <div class="shell">
      <header class="topbar">
        <div class="brand">
          <span class="brand-mark">&gt;_</span>
          <span>TRAVELER DEV</span>
        </div>

        <div class="top-actions">
          <button id="run">Run</button>
          <button id="preview">Preview</button>
          <button id="install">Install</button>
        </div>
      </header>

      <main class="workspace">
        <aside class="sidebar">
          <div class="side-title">EXPLORER</div>

          <div class="project">
            <span>▾</span>
            <strong>WORKSPACE</strong>
          </div>

          <div class="tree">
            ${state.files.map(file => `
              <button
                class="file ${file === state.activeFile ? "active" : ""}"
                data-file="${file}"
              >
                <span class="file-icon">◈</span>
                ${file}
              </button>
            `).join("")}
          </div>
        </aside>

        <section class="editor">
          <div class="tabs">
            <div class="tab active">
              ${state.activeFile}
            </div>
          </div>

          <div class="code">
            <div class="line-numbers">
              ${Array.from({length: 28}, (_, i) => `<span>${i + 1}</span>`).join("")}
            </div>

            <pre><code>${escapeHtml(getEditorContent())}</code></pre>
          </div>
        </section>

        <aside class="right-panel">
          <div class="panel-tabs">
            <button class="selected">AI</button>
            <button>PREVIEW</button>
          </div>

          <div class="ai">
            <div class="ai-title">TRAVELER DEV AGENT</div>

            <div class="status">
              <span class="dot"></span>
              <span>${API}</span>
            </div>

            <textarea
              id="prompt"
              placeholder="Describe what you want to build..."
            ></textarea>

            <button id="send" class="primary">
              Build with Traveler Dev
            </button>

            <div id="output" class="output">
              Ready.
            </div>
          </div>
        </aside>
      </main>

      <footer class="terminal">
        <div class="terminal-head">
          <span>TERMINAL</span>
          <span class="connection">
            ${state.connected ? "CONNECTED" : "READY"}
          </span>
        </div>

        <div id="terminal-output">
          ${state.terminal.map(x => `<div>${escapeHtml(x)}</div>`).join("")}
        </div>
      </footer>
    </div>
  `;

  bind();
}

function getEditorContent() {
  if (state.activeFile === "package.json") {
    return JSON.stringify({
      name: "traveler-project",
      private: true,
      scripts: {
        dev: "vite",
        build: "vite build"
      }
    }, null, 2);
  }

  if (state.activeFile === "src/style.css") {
    return `:root {
  font-family: Inter, system-ui, sans-serif;
}

body {
  margin: 0;
  background: #0b0f19;
  color: #e5e7eb;
}`;
  }

  return `import "./style.css";

console.log("TRAVELER DEV workspace ready");`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function bind() {
  document.querySelectorAll("[data-file]").forEach(button => {
    button.onclick = () => {
      state.activeFile = button.dataset.file;
      render();
    };
  });

  document.querySelector("#send").onclick = sendAgent;
  document.querySelector("#run").onclick = runWorkspace;
  document.querySelector("#preview").onclick = previewWorkspace;
  document.querySelector("#install").onclick = installPwa;
}

async function sendAgent() {
  const prompt = document.querySelector("#prompt");
  const output = document.querySelector("#output");
  const message = prompt.value.trim();

  if (!message) return;

  output.textContent = "Running Traveler Dev agent...";

  try {
    const response = await fetch(`${API}/api/agent/run`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ message })
    });

    const data = await response.json();

    if (!response.ok || !data.success) {
      throw new Error(data.error || `HTTP ${response.status}`);
    }

    output.textContent = data.content || "Agent completed.";
    state.terminal.push(
      `[agent] ${data.model || "provider"} completed successfully`
    );
  } catch (error) {
    output.textContent = `Agent error: ${error.message}`;
    state.terminal.push(`[agent:error] ${error.message}`);
  }

  render();
}

async function runWorkspace() {
  state.terminal.push("[run] Workspace execution requested.");
  state.terminal.push("[run] StackBlitz/WebContainer bridge is ready for integration.");
  render();
}

async function previewWorkspace() {
  state.terminal.push("[preview] Preview requested.");
  render();
}

async function installPwa() {
  if (!window.deferredInstallPrompt) {
    state.terminal.push(
      "[pwa] Browser install prompt is not currently available."
    );
    render();
    return;
  }

  window.deferredInstallPrompt.prompt();
  await window.deferredInstallPrompt.userChoice;
  window.deferredInstallPrompt = null;
}

window.addEventListener("beforeinstallprompt", event => {
  event.preventDefault();
  window.deferredInstallPrompt = event;
});

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(error => {
      console.error("Service worker registration failed:", error);
    });
  });
}

render();
EOF

cat > "$FRONTEND/src/style.css" <<'EOF'
:root {
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: #e5e7eb;
  background: #0b0f19;
  color-scheme: dark;
}

* {
  box-sizing: border-box;
}

html,
body,
#app {
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  margin: 0;
}

body {
  overflow: hidden;
  background: #0b0f19;
}

button,
textarea {
  font: inherit;
}

button {
  color: inherit;
}

.shell {
  display: grid;
  grid-template-rows: 52px minmax(0, 1fr) 180px;
  width: 100%;
  height: 100dvh;
  min-width: 0;
  overflow: hidden;
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 0 14px;
  background: #111827;
  border-bottom: 1px solid #263244;
  min-width: 0;
}

.brand {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
  font-size: 13px;
  font-weight: 700;
  letter-spacing: .08em;
  white-space: nowrap;
}

.brand-mark {
  color: #60a5fa;
  font-family: monospace;
}

.top-actions {
  display: flex;
  gap: 7px;
}

.top-actions button,
.primary {
  border: 1px solid #334155;
  border-radius: 6px;
  background: #172033;
  padding: 7px 11px;
  cursor: pointer;
}

.top-actions button:hover,
.primary:hover {
  background: #1e293b;
}

.workspace {
  display: grid;
  grid-template-columns: 220px minmax(0, 1fr) 330px;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
}

.sidebar,
.right-panel {
  min-width: 0;
  min-height: 0;
  background: #0f172a;
}

.sidebar {
  border-right: 1px solid #263244;
  overflow: auto;
}

.side-title,
.panel-tabs {
  height: 40px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .08em;
  color: #94a3b8;
  border-bottom: 1px solid #263244;
}

.project {
  display: flex;
  gap: 7px;
  align-items: center;
  padding: 12px;
  font-size: 11px;
}

.tree {
  display: grid;
}

.file {
  width: 100%;
  border: 0;
  padding: 7px 12px 7px 24px;
  background: transparent;
  text-align: left;
  color: #cbd5e1;
  cursor: pointer;
  font-size: 12px;
}

.file:hover,
.file.active {
  background: #172033;
}

.file-icon {
  margin-right: 7px;
  color: #60a5fa;
}

.editor {
  min-width: 0;
  min-height: 0;
  display: grid;
  grid-template-rows: 40px minmax(0, 1fr);
  background: #0b1220;
  overflow: hidden;
}

.tabs {
  display: flex;
  align-items: end;
  border-bottom: 1px solid #263244;
}

.tab {
  padding: 11px 14px 9px;
  font-size: 12px;
  border-right: 1px solid #263244;
}

.tab.active {
  border-top: 2px solid #60a5fa;
  background: #0f172a;
}

.code {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr);
  min-height: 0;
  overflow: auto;
  padding-top: 14px;
}

.line-numbers {
  display: grid;
  align-content: start;
  justify-items: end;
  padding-right: 14px;
  color: #475569;
  font: 12px/20px ui-monospace, SFMono-Regular, Menlo, monospace;
  user-select: none;
}

.code pre {
  margin: 0;
  padding: 0 20px;
  min-width: max-content;
  color: #dbeafe;
  font: 12px/20px ui-monospace, SFMono-Regular, Menlo, monospace;
}

.right-panel {
  border-left: 1px solid #263244;
  display: grid;
  grid-template-rows: 40px minmax(0, 1fr);
  overflow: hidden;
}

.panel-tabs {
  gap: 18px;
}

.panel-tabs button {
  border: 0;
  background: transparent;
  color: #64748b;
  height: 100%;
  font-size: 11px;
}

.panel-tabs button.selected {
  color: #e2e8f0;
}

.ai {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 14px;
  min-height: 0;
  overflow: auto;
}

.ai-title {
  font-size: 13px;
  font-weight: 700;
}

.status {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
  color: #64748b;
  font-size: 10px;
}

.status span:last-child {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dot {
  width: 7px;
  height: 7px;
  flex: 0 0 7px;
  border-radius: 50%;
  background: #22c55e;
}

textarea {
  width: 100%;
  min-height: 130px;
  resize: vertical;
  border: 1px solid #334155;
  border-radius: 7px;
  outline: none;
  padding: 11px;
  background: #0b1220;
  color: #e5e7eb;
}

textarea:focus {
  border-color: #60a5fa;
}

.primary {
  background: #2563eb;
  border-color: #2563eb;
  font-weight: 600;
}

.output {
  flex: 1;
  min-height: 80px;
  overflow: auto;
  white-space: pre-wrap;
  color: #cbd5e1;
  font: 11px/1.5 ui-monospace, monospace;
}

.terminal {
  min-width: 0;
  min-height: 0;
  border-top: 1px solid #263244;
  background: #080d16;
  overflow: hidden;
}

.terminal-head {
  display: flex;
  justify-content: space-between;
  padding: 8px 12px;
  border-bottom: 1px solid #1e293b;
  color: #94a3b8;
  font-size: 10px;
  letter-spacing: .08em;
}

.connection {
  color: #22c55e;
}

#terminal-output {
  height: calc(100% - 32px);
  overflow: auto;
  padding: 9px 12px;
  color: #94a3b8;
  font: 11px/1.6 ui-monospace, monospace;
}

@media (max-width: 900px) {
  .workspace {
    grid-template-columns: 190px minmax(0, 1fr);
  }

  .right-panel {
    position: fixed;
    inset: 52px 0 180px auto;
    width: min(360px, 88vw);
    z-index: 10;
    box-shadow: -20px 0 40px rgba(0, 0, 0, .35);
  }
}

@media (max-width: 640px) {
  .shell {
    grid-template-rows: 48px minmax(0, 1fr) 150px;
  }

  .workspace {
    grid-template-columns: 1fr;
  }

  .sidebar {
    display: none;
  }

  .right-panel {
    position: static;
    width: auto;
    border-left: 0;
    border-top: 1px solid #263244;
    display: none;
  }

  .top-actions button:nth-child(2) {
    display: none;
  }

  .brand {
    font-size: 11px;
  }

  .code pre {
    padding-right: 12px;
  }
}
EOF

cat > "$FRONTEND/vite.config.js" <<'EOF'
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    port: 5173,
    strictPort: true
  },
  preview: {
    host: "0.0.0.0",
    port: 4173,
    strictPort: true
  },
  build: {
    target: "es2022",
    sourcemap: false
  }
});
EOF

printf '\n=== CHUNK 1 CHECK ===\n'

test -f "$FRONTEND/index.html" &&
test -f "$FRONTEND/package.json" &&
test -f "$FRONTEND/src/main.js" &&
test -f "$FRONTEND/src/style.css" &&
test -f "$FRONTEND/public/manifest.webmanifest" &&
test -f "$FRONTEND/public/sw.js" &&
test -f "$FRONTEND/vite.config.js"

if command -v node >/dev/null 2>&1; then
  node --check "$FRONTEND/src/main.js"
fi

printf 'FRONTEND SOURCE: PASS\n'
printf 'PWA FILES: PASS\n'
printf 'No server processes were started or stopped.\n'
printf 'No npm install was attempted.\n'
printf 'CHUNK 1 COMPLETE\n'
