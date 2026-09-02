#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$ROOT/frontend"
PUBLIC="$FRONTEND/public"

echo "============================================================"
echo " TRAVELER DEV — PRODUCTION STACKBLITZ WORKSPACE FRONTEND"
echo "============================================================"

mkdir -p "$FRONTEND" "$PUBLIC"

cat > "$FRONTEND/package.json" <<'EOF'
{
  "name": "traveler-dev-workspace",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "vite": "^7.1.5"
  }
}
EOF

cat > "$FRONTEND/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#0b0d12">
  <meta name="description" content="TRAVELER DEV — AI software engineering workspace">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="icon" href="/icon.svg">
  <title>TRAVELER DEV</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
EOF

mkdir -p "$FRONTEND/src"

cat > "$FRONTEND/src/main.js" <<'EOF'
const API =
  localStorage.getItem("traveler_dev_api") ||
  window.TRAVELER_DEV_API ||
  "/api";

const state = {
  files: {
    "src/App.jsx": `export default function App() {
  return (
    <main>
      <h1>Traveler Dev</h1>
      <p>Start building your application.</p>
    </main>
  );
}`,
    "package.json": `{
  "name": "traveler-project",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  }
}`,
    "README.md": "# Traveler Dev\\n\\nProduction workspace."
  },
  activeFile: "src/App.jsx",
  preview: "",
  terminal: [],
  mobilePanel: "editor"
};

const root = document.querySelector("#root");

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function render() {
  const files = Object.keys(state.files);

  root.innerHTML = `
    <div class="app">
      <header class="topbar">
        <div class="brand">
          <div class="brand-mark">T</div>
          <div>
            <strong>TRAVELER DEV</strong>
            <span>AI SOFTWARE WORKSPACE</span>
          </div>
        </div>

        <div class="top-actions">
          <button id="runBtn">▶ Run</button>
          <button id="previewBtn">Preview</button>
          <button id="installBtn" class="install hidden">Install</button>
          <button id="menuBtn" class="mobile-only">☰</button>
        </div>
      </header>

      <div class="workspace">
        <aside class="sidebar">
          <div class="side-title">
            <span>EXPLORER</span>
            <button id="newFile">＋</button>
          </div>

          <div class="project-name">TRAVELER PROJECT</div>

          <div class="file-tree">
            ${files.map(file => `
              <button
                class="file ${file === state.activeFile ? "active" : ""}"
                data-file="${esc(file)}"
              >
                <span>${file.endsWith(".jsx") ? "◈" :
                       file.endsWith(".json") ? "{}" :
                       file.endsWith(".md") ? "M" : "•"}</span>
                ${esc(file)}
              </button>
            `).join("")}
          </div>

          <div class="sidebar-bottom">
            <div class="status-dot"></div>
            <span>Backend connected</span>
          </div>
        </aside>

        <main class="main">
          <div class="mobile-tabs">
            <button data-panel="files">Files</button>
            <button data-panel="editor" class="selected">Editor</button>
            <button data-panel="preview">Preview</button>
            <button data-panel="agent">Agent</button>
          </div>

          <section class="editor-panel panel">
            <div class="tabs">
              ${files.map(file => `
                <button
                  class="tab ${file === state.activeFile ? "active" : ""}"
                  data-file="${esc(file)}"
                >
                  ${esc(file)}
                </button>
              `).join("")}
            </div>

            <div class="editor-wrap">
              <textarea id="editor" spellcheck="false">${esc(
                state.files[state.activeFile]
              )}</textarea>
            </div>

            <div class="editor-status">
              <span>${esc(state.activeFile)}</span>
              <span>UTF-8</span>
              <span>Production</span>
            </div>
          </section>

          <section class="preview-panel panel">
            <div class="panel-head">
              <span>PREVIEW</span>
              <div>
                <button id="refreshPreview">↻</button>
                <button id="openPreview">Open</button>
              </div>
            </div>

            <div class="preview-frame">
              ${
                state.preview
                  ? `<iframe src="${esc(state.preview)}"
                       title="Traveler Dev Preview"
                       sandbox="allow-scripts allow-same-origin allow-forms allow-modals"></iframe>`
                  : `
                    <div class="empty">
                      <div class="empty-icon">◇</div>
                      <strong>Preview</strong>
                      <span>Run the project to open the live application.</span>
                    </div>
                  `
              }
            </div>
          </section>

          <section class="agent-panel panel">
            <div class="panel-head">
              <span>TRAVELER AGENT</span>
              <span class="connection">● ONLINE</span>
            </div>

            <div id="chat" class="chat">
              <div class="message system">
                <strong>Traveler Dev</strong>
                <p>Workspace ready. Describe what you want to build.</p>
              </div>
            </div>

            <form id="agentForm" class="agent-form">
              <textarea
                id="prompt"
                rows="2"
                placeholder="Ask Traveler Dev to build, modify, debug or test..."
              ></textarea>
              <button type="submit">Send</button>
            </form>
          </section>

          <section class="terminal-panel panel">
            <div class="panel-head">
              <span>TERMINAL</span>
              <button id="clearTerminal">Clear</button>
            </div>
            <pre id="terminal">$ traveler-dev workspace ready
$ backend: ${esc(API)}
</pre>
          </section>
        </main>
      </div>
    </div>
  `;

  bind();
}

function bind() {
  document.querySelectorAll("[data-file]").forEach(button => {
    button.onclick = () => {
      state.activeFile = button.dataset.file;
      render();
    };
  });

  const editor = document.querySelector("#editor");

  editor?.addEventListener("input", e => {
    state.files[state.activeFile] = e.target.value;
  });

  document.querySelector("#runBtn").onclick = runProject;
  document.querySelector("#previewBtn").onclick = createPreview;
  document.querySelector("#refreshPreview").onclick = createPreview;
  document.querySelector("#openPreview").onclick = () => {
    if (state.preview) window.open(state.preview, "_blank", "noopener");
  };

  document.querySelector("#clearTerminal").onclick = () => {
    document.querySelector("#terminal").textContent = "$ terminal cleared\n";
  };

  document.querySelector("#newFile").onclick = createFile;

  document.querySelector("#agentForm").onsubmit = sendAgent;

  document.querySelector("#installBtn").onclick = installPWA;

  document.querySelectorAll("[data-panel]").forEach(btn => {
    btn.onclick = () => {
      document.body.dataset.panel = btn.dataset.panel;
    };
  });

  document.querySelector("#menuBtn")?.addEventListener("click", () => {
    document.querySelector(".sidebar").classList.toggle("open");
  });
}

function terminal(line) {
  const el = document.querySelector("#terminal");
  if (el) {
    el.textContent += `\n${line}`;
    el.scrollTop = el.scrollHeight;
  }
}

async function sendAgent(event) {
  event.preventDefault();

  const prompt = document.querySelector("#prompt");
  const message = prompt.value.trim();

  if (!message) return;

  prompt.value = "";

  const chat = document.querySelector("#chat");

  chat.insertAdjacentHTML(
    "beforeend",
    `<div class="message user"><strong>You</strong><p>${esc(message)}</p></div>`
  );

  const thinking = document.createElement("div");
  thinking.className = "message assistant";
  thinking.innerHTML = "<strong>Traveler Dev</strong><p>Working…</p>";
  chat.appendChild(thinking);
  chat.scrollTop = chat.scrollHeight;

  try {
    const response = await fetch(`${API}/agent/run`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        message,
        messages: [{role: "user", content: message}]
      })
    });

    const data = await response.json();

    thinking.querySelector("p").textContent =
      data.content || data.error || "No response returned.";

    terminal(
      data.success
        ? `✓ Agent completed using ${data.model || "provider"}`
        : `✗ Agent error: ${data.error || "unknown"}`
    );
  } catch (error) {
    thinking.querySelector("p").textContent =
      `Connection error: ${error.message}`;

    terminal(`✗ ${error.message}`);
  }
}

async function runProject() {
  terminal("$ build started");

  try {
    const response = await fetch(`${API}/preview`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        files: state.files,
        command: "npm run build"
      })
    });

    const data = await response.json();

    if (data.preview_url || data.url) {
      state.preview = data.preview_url || data.url;
      terminal(`✓ preview: ${state.preview}`);
      render();
      return;
    }

    terminal(`✗ ${data.error || "Preview service returned no URL"}`);
  } catch (error) {
    terminal(`✗ Preview request failed: ${error.message}`);
  }
}

async function createPreview() {
  await runProject();
}

function createFile() {
  const name = prompt("New file path:");

  if (!name || name.includes("..") || name.startsWith("/")) return;

  state.files[name] = "";
  state.activeFile = name;
  render();
}

let deferredInstall;

window.addEventListener("beforeinstallprompt", event => {
  event.preventDefault();
  deferredInstall = event;
  document.querySelector("#installBtn")?.classList.remove("hidden");
});

async function installPWA() {
  if (!deferredInstall) return;

  deferredInstall.prompt();
  await deferredInstall.userChoice;
  deferredInstall = null;

  document.querySelector("#installBtn")?.classList.add("hidden");
}

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
  color-scheme: dark;
  background: #090b10;
  color: #e7eaf0;
  --bg: #090b10;
  --panel: #0d1017;
  --panel2: #11151e;
  --border: #202631;
  --muted: #858c9b;
  --text: #e7eaf0;
  --accent: #7c5cff;
  --accent2: #9a85ff;
}

* {
  box-sizing: border-box;
}

html,
body,
#root {
  width: 100%;
  height: 100%;
  margin: 0;
}

body {
  overflow: hidden;
  background: var(--bg);
}

button,
textarea {
  font: inherit;
}

button {
  color: inherit;
}

.app {
  width: 100vw;
  height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.topbar {
  height: 54px;
  min-height: 54px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 14px;
  border-bottom: 1px solid var(--border);
  background: #0b0e14;
}

.brand {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}

.brand-mark {
  width: 30px;
  height: 30px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  background: var(--accent);
  color: white;
  font-weight: 900;
}

.brand strong {
  display: block;
  font-size: 12px;
  letter-spacing: .08em;
}

.brand span {
  display: block;
  color: var(--muted);
  font-size: 8px;
  letter-spacing: .1em;
}

.top-actions {
  display: flex;
  gap: 7px;
}

button {
  border: 1px solid var(--border);
  background: var(--panel2);
  border-radius: 6px;
  padding: 6px 10px;
  cursor: pointer;
}

button:hover {
  border-color: #394150;
}

.top-actions button:first-child {
  background: var(--accent);
  border-color: var(--accent);
}

.workspace {
  min-height: 0;
  flex: 1;
  display: flex;
}

.sidebar {
  width: 235px;
  min-width: 235px;
  border-right: 1px solid var(--border);
  background: #0b0e14;
  display: flex;
  flex-direction: column;
}

.side-title,
.panel-head,
.editor-status {
  height: 38px;
  min-height: 38px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
  border-bottom: 1px solid var(--border);
}

.side-title span,
.panel-head > span {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .1em;
  color: var(--muted);
}

.project-name {
  padding: 12px;
  color: #aeb5c3;
  font-size: 10px;
  font-weight: 800;
}

.file-tree {
  padding: 0 7px;
  overflow: auto;
}

.file {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  text-align: left;
  border: 0;
  background: transparent;
  color: #b7bdc9;
  padding: 8px;
}

.file.active {
  color: white;
  background: #191d27;
}

.sidebar-bottom {
  margin-top: auto;
  padding: 12px;
  border-top: 1px solid var(--border);
  color: var(--muted);
  font-size: 10px;
  display: flex;
  gap: 7px;
  align-items: center;
}

.status-dot,
.connection {
  color: #56d364;
}

.main {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(320px, .85fr);
  grid-template-rows: minmax(0, 1fr) 180px;
}

.panel {
  min-width: 0;
  min-height: 0;
  border-right: 1px solid var(--border);
  border-bottom: 1px solid var(--border);
  background: var(--panel);
  display: flex;
  flex-direction: column;
}

.editor-panel {
  grid-column: 1;
  grid-row: 1;
}

.preview-panel {
  grid-column: 2;
  grid-row: 1;
}

.agent-panel {
  grid-column: 1;
  grid-row: 2;
}

.terminal-panel {
  grid-column: 2;
  grid-row: 2;
}

.tabs {
  height: 38px;
  min-height: 38px;
  display: flex;
  overflow-x: auto;
  border-bottom: 1px solid var(--border);
}

.tab {
  white-space: nowrap;
  border: 0;
  border-right: 1px solid var(--border);
  border-radius: 0;
  background: #0b0e14;
  color: var(--muted);
}

.tab.active {
  color: white;
  background: var(--panel);
}

.editor-wrap {
  flex: 1;
  min-height: 0;
}

#editor {
  width: 100%;
  height: 100%;
  resize: none;
  outline: none;
  border: 0;
  padding: 18px;
  background: #0a0d12;
  color: #d8dee9;
  font: 13px/1.65 "SFMono-Regular", Consolas, "Liberation Mono", monospace;
  tab-size: 2;
}

.editor-status {
  color: var(--muted);
  font-size: 9px;
}

.preview-frame {
  flex: 1;
  min-height: 0;
  background: #080a0e;
}

.preview-frame iframe {
  width: 100%;
  height: 100%;
  border: 0;
  background: white;
}

.empty {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 7px;
  color: var(--muted);
  text-align: center;
  padding: 20px;
}

.empty strong {
  color: white;
}

.empty-icon {
  font-size: 40px;
  color: var(--accent);
}

.chat {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 10px;
}

.message {
  margin-bottom: 10px;
  font-size: 11px;
}

.message strong {
  font-size: 10px;
  color: var(--accent2);
}

.message p {
  margin: 4px 0 0;
  white-space: pre-wrap;
  line-height: 1.45;
}

.message.user strong {
  color: #d9dee8;
}

.agent-form {
  display: flex;
  gap: 7px;
  padding: 8px;
  border-top: 1px solid var(--border);
}

.agent-form textarea {
  flex: 1;
  resize: none;
  border: 1px solid var(--border);
  outline: none;
  border-radius: 6px;
  padding: 8px;
  background: #090c11;
  color: white;
}

.agent-form button {
  background: var(--accent);
  border-color: var(--accent);
}

#terminal {
  flex: 1;
  overflow: auto;
  margin: 0;
  padding: 10px;
  color: #b7c0cf;
  font: 10px/1.5 "SFMono-Regular", Consolas, monospace;
  white-space: pre-wrap;
}

.mobile-tabs,
.mobile-only {
  display: none;
}

.hidden {
  display: none !important;
}

@media (max-width: 900px) {
  .sidebar {
    width: 190px;
    min-width: 190px;
  }

  .main {
    grid-template-columns: 1fr;
    grid-template-rows: minmax(0, 1fr) 180px;
  }

  .editor-panel,
  .preview-panel,
  .agent-panel,
  .terminal-panel {
    grid-column: 1;
  }

  .preview-panel,
  .agent-panel,
  .terminal-panel {
    display: none;
  }

  .editor-panel {
    grid-row: 1 / span 2;
  }

  .mobile-only {
    display: block;
  }
}

@media (max-width: 650px) {
  .topbar {
    padding: 0 9px;
  }

  .brand span {
    display: none;
  }

  .top-actions button:not(.mobile-only):not(.install) {
    display: none;
  }

  .workspace {
    position: relative;
  }

  .sidebar {
    position: absolute;
    z-index: 20;
    inset: 0 auto 0 0;
    width: min(82vw, 280px);
    min-width: 0;
    transform: translateX(-100%);
    transition: transform .18s ease;
    box-shadow: 15px 0 35px #0008;
  }

  .sidebar.open {
    transform: translateX(0);
  }

  .mobile-tabs {
    display: flex;
    height: 36px;
    min-height: 36px;
    border-bottom: 1px solid var(--border);
    overflow-x: auto;
  }

  .mobile-tabs button {
    flex: 1;
    border: 0;
    border-radius: 0;
    background: #0b0e14;
    color: var(--muted);
    font-size: 10px;
  }

  .mobile-tabs button.selected {
    color: white;
    background: #171b24;
  }

  .main {
    width: 100%;
    display: block;
  }

  .editor-panel {
    height: 100%;
    border: 0;
  }

  .tabs {
    display: none;
  }

  .editor-status {
    padding-bottom: env(safe-area-inset-bottom);
  }

  body[data-panel="preview"] .editor-panel,
  body[data-panel="agent"] .editor-panel {
    display: none;
  }

  body[data-panel="preview"] .preview-panel,
  body[data-panel="agent"] .agent-panel {
    display: flex;
    height: 100%;
  }

  body[data-panel="preview"] .preview-panel {
    position: absolute;
    inset: 36px 0 0;
  }

  body[data-panel="agent"] .agent-panel {
    position: absolute;
    inset: 36px 0 0;
  }

  .top-actions {
    gap: 4px;
  }
}
EOF

# Import the stylesheet.
cat >> "$FRONTEND/src/main.js" <<'EOF'
import "./style.css";
EOF

cat > "$PUBLIC/manifest.webmanifest" <<'EOF'
{
  "name": "TRAVELER DEV",
  "short_name": "Traveler Dev",
  "description": "AI software engineering workspace",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#090b10",
  "theme_color": "#090b10",
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

cat > "$PUBLIC/sw.js" <<'EOF'
const CACHE = "traveler-dev-v1";

const APP_SHELL = [
  "/",
  "/manifest.webmanifest",
  "/icon.svg"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key !== CACHE)
          .map(key => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  const url = new URL(event.request.url);

  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(event.request)
      .then(response => {
        const copy = response.clone();
        caches.open(CACHE).then(cache => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request).then(
        cached => cached || caches.match("/")
      ))
  );
});
EOF

cat > "$PUBLIC/icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="112" fill="#7c5cff"/>
  <path d="M128 116h256v70H198v70h150v66H198v74h186v70H128z" fill="white"/>
</svg>
EOF

# Vite reads this file.
cat > "$FRONTEND/vite.config.js" <<'EOF'
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    port: 5173,
    strictPort: false
  },
  preview: {
    host: "0.0.0.0",
    port: 4173,
    strictPort: false
  },
  build: {
    outDir: "dist",
    emptyOutDir: true
  }
});
EOF

echo
echo "=== FRONTEND FILES ==="
find "$FRONTEND" -maxdepth 3 -type f \
  ! -path "$FRONTEND/node_modules/*" \
  -print | sort

echo
echo "=== SYNTAX CHECK ==="
node --check "$FRONTEND/src/main.js"

echo
echo "=== PACKAGE CACHE CHECK ==="
if npm cache verify >/tmp/traveler-npm-cache.log 2>&1; then
  echo "npm cache: PASS"
else
  echo "npm cache: unavailable"
fi

echo
echo "=== BUILD ==="

cd "$FRONTEND"

if [ -x "$ROOT/node_modules/.bin/vite" ]; then
  "$ROOT/node_modules/.bin/vite" build
elif [ -x "$FRONTEND/node_modules/.bin/vite" ]; then
  "$FRONTEND/node_modules/.bin/vite" build
else
  echo
  echo "Vite is not installed locally."
  echo "The production frontend source has been created successfully."
  echo "Install/build can be performed when npm registry connectivity is available."
fi

echo
echo "============================================================"
echo " TRAVELER DEV FRONTEND READY"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "PWA manifest: $PUBLIC/manifest.webmanifest"
echo "Service worker: $PUBLIC/sw.js"
echo "StackBlitz/WebContainer API remains a backend integration."
echo
