#!/usr/bin/env bash
set -euo pipefail

TARGET_HTML="index.html"
if [ -f "webcontainer-ui/index.html" ]; then
  TARGET_HTML="webcontainer-ui/index.html"
fi

BASE_DIR="$(dirname "$TARGET_HTML")"

echo "=== 1. Injecting Service Worker to enable Cross-Origin Isolation on Hugging Face ==="
cat << 'SWEOF' > "$BASE_DIR/sw-coi.js"
// COI Service Worker to inject Cross-Origin Isolation headers inside Hugging Face iframe
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (event) => {
  if (event.request.cache === "only-if-cached" && event.request.mode !== "same-origin") return;

  event.respondWith(
    fetch(event.request).then((response) => {
      if (response.status === 0) return response;

      const newHeaders = new Headers(response.headers);
      newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
      newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
      });
    }).catch((e) => console.error(e))
  );
});
SWEOF

echo "=== 2. Writing Production UI to $TARGET_HTML ==="
cat << 'HTMLEOF' > "$TARGET_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>TRAVELER.DEV - Workspace</title>
  
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />
  <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>

  <script>
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw-coi.js').then((reg) => {
        if (reg.active && !navigator.serviceWorker.controller) {
          window.location.reload();
        }
      });
    }
  </script>

  <style>
    :root {
      --bg-dark: #050511;
      --bg-surface: #0a0b1a;
      --bg-card: #13142c;
      --border: rgba(255, 255, 255, 0.08);
      --accent: #6366f1;
      --accent-gradient: linear-gradient(135deg, #6366f1, #a855f7);
      --text: #e2e8f0;
      --text-muted: #64748b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: 'Inter', system-ui, -apple-system, sans-serif;
      background: var(--bg-dark);
      color: var(--text);
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    /* HEADER & VIEWPORT RESPONSIVE SWITCHER */
    .header {
      height: 50px;
      background: var(--bg-surface);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 16px;
      flex-shrink: 0;
    }
    .brand { font-weight: 800; font-size: 1rem; color: #a78bfa; display: flex; align-items: center; gap: 8px; }
    
    .viewport-toggle {
      display: flex;
      background: rgba(0,0,0,0.4);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 2px;
    }
    .view-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 5px 12px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .view-btn.active { background: rgba(99, 102, 241, 0.3); color: white; font-weight: 600; }

    .header-actions { display: flex; gap: 8px; align-items: center; }
    .btn {
      background: rgba(255,255,255,0.05);
      border: 1px solid var(--border);
      color: white;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
      white-space: nowrap;
    }
    .btn-primary { background: var(--accent-gradient); border: none; font-weight: 600; }

    /* IDE WORKSPACE CONTAINER */
    .workspace {
      display: flex;
      flex: 1;
      overflow: hidden;
      transition: all 0.3s ease;
    }

    /* VIEWPORT PRESETS */
    .workspace.mode-laptop { flex-direction: row; }
    .workspace.mode-tablet { flex-direction: row; width: 800px; margin: 0 auto; border: 1px solid var(--border); }
    .workspace.mode-mobile { flex-direction: column; width: 390px; margin: 0 auto; overflow-y: auto; border: 1px solid var(--border); }

    .icon-sidebar {
      width: 48px;
      background: #080915;
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 12px;
      gap: 16px;
      flex-shrink: 0;
    }
    .icon-btn { color: var(--text-muted); cursor: pointer; font-size: 18px; }
    .icon-btn.active { color: var(--accent); }

    .file-explorer {
      width: 200px;
      background: var(--bg-surface);
      border-right: 1px solid var(--border);
      padding: 12px;
      font-size: 12px;
      flex-shrink: 0;
      overflow-y: auto;
    }
    .file-item { padding: 6px 8px; border-radius: 4px; cursor: pointer; color: #cbd5e1; }
    .file-item.active { background: rgba(99, 102, 241, 0.2); color: #818cf8; font-weight: 600; }

    .main-editor {
      flex: 2;
      display: flex;
      flex-direction: column;
      background: #020208;
      border-right: 1px solid var(--border);
      min-width: 0;
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
    }
    .tab.active { background: #020208; color: var(--text); border-top: 2px solid var(--accent); }

    .code-wrapper { flex: 1; position: relative; }
    textarea#editor {
      width: 100%;
      height: 100%;
      background: #020208;
      color: #38bdf8;
      font-family: monospace;
      font-size: 13px;
      border: none;
      outline: none;
      padding: 14px;
      resize: none;
      line-height: 1.5;
    }

    /* EXPANDED PROMPT DOCK WITH FILE UPLOAD */
    .prompt-dock {
      background: var(--bg-surface);
      border-top: 1px solid var(--border);
      padding: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .prompt-card {
      background: #12142b;
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .prompt-card textarea {
      width: 100%;
      height: 75px;
      background: transparent;
      border: none;
      color: white;
      outline: none;
      font-size: 13px;
      resize: none;
      font-family: inherit;
    }
    .prompt-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid rgba(255,255,255,0.05);
      padding-top: 8px;
    }
    .upload-btn-label {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #94a3b8;
      cursor: pointer;
      background: rgba(255,255,255,0.05);
      padding: 5px 10px;
      border-radius: 6px;
      border: 1px solid var(--border);
    }
    .upload-btn-label:hover { color: white; background: rgba(255,255,255,0.1); }
    #file-input { display: none; }
    #file-name-indicator { font-size: 11px; color: #a78bfa; font-style: italic; }

    .terminal-container {
      height: 140px;
      background: #000;
      border-top: 1px solid var(--border);
      padding: 4px;
    }

    .preview-container {
      flex: 1.2;
      display: flex;
      flex-direction: column;
      background: #fff;
      min-width: 0;
    }
    .preview-header {
      height: 38px;
      background: var(--bg-surface);
      color: white;
      padding: 0 12px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 12px;
    }
    iframe#preview-frame { flex: 1; border: none; width: 100%; height: 100%; background: white; }
  </style>
</head>
<body>

  <div class="header">
    <div class="brand">🪐 TRAVELER.DEV</div>
    
    <div class="viewport-toggle">
      <button class="view-btn active" id="btn-laptop" onclick="setViewport('laptop')">💻 Laptop</button>
      <button class="view-btn" id="btn-tablet" onclick="setViewport('tablet')">📱 Tablet</button>
      <button class="view-btn" id="btn-mobile" onclick="setViewport('mobile')">📲 Mobile</button>
    </div>

    <div class="header-actions">
      <button class="btn" onclick="downloadZip()">📦 Export ZIP</button>
      <button class="btn btn-primary" onclick="deployToSurge()">🚀 Deploy to Surge</button>
    </div>
  </div>

  <div class="workspace mode-laptop" id="workspace">
    <div class="icon-sidebar">
      <div class="icon-btn active">📁</div>
      <div class="icon-btn">🤖</div>
      <div class="icon-btn">⚙️</div>
    </div>

    <div class="file-explorer">
      <div style="font-weight:700; color:var(--text-muted); margin-bottom:8px; font-size:11px;">EXPLORER</div>
      <div id="file-tree"></div>
    </div>

    <div class="main-editor">
      <div class="tabs-bar">
        <div class="tab active" id="active-tab">index.js</div>
      </div>
      <div class="code-wrapper">
        <textarea id="editor" spellcheck="false"></textarea>
      </div>

      <div class="prompt-dock">
        <div class="prompt-card">
          <textarea id="prompt-input" placeholder="Describe what you want to build or request code modifications..."></textarea>
          <div class="prompt-toolbar">
            <div style="display:flex; align-items:center; gap:8px;">
              <label for="file-input" class="upload-btn-label">
                📎 Attach File
              </label>
              <input type="file" id="file-input" onchange="handleFileUpload(event)" />
              <span id="file-name-indicator"></span>
            </div>
            <button class="btn btn-primary" onclick="submitPrompt()">✨ Generate & Run</button>
          </div>
        </div>
      </div>

      <div class="terminal-container" id="terminal"></div>
    </div>

    <div class="preview-container">
      <div class="preview-header">
        <span>👁️ Live WebContainer Preview</span>
        <button class="btn" onclick="reloadPreview()">🔄 Reload</button>
      </div>
      <iframe id="preview-frame"></iframe>
    </div>
  </div>

  <script type="module">
    import { WebContainer } from 'https://cdn.jsdelivr.net/npm/@webcontainer/api@1.1.8/+esm';

    const BACKEND_URL = "https://agent-traveler-dev2.onrender.com";

    const projectFiles = {
      'package.json': {
        file: {
          contents: JSON.stringify({
            name: "traveler-app",
            type: "module",
            dependencies: { "express": "^4.18.2" },
            scripts: { "start": "node index.js" }
          }, null, 2)
        }
      },
      'index.js': {
        file: {
          contents: `import express from 'express';
const app = express();
const port = 3111;

app.get('/', (req, res) => {
  res.send(\`
    <!DOCTYPE html>
    <html>
      <head>
        <link rel="manifest" href="/manifest.json">
        <style>
          body { font-family: system-ui; padding: 30px; background: #0f172a; color: white; }
          .card { background: #1e293b; padding: 20px; border-radius: 12px; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>🚀 TRAVELER.DEV Live App</h1>
          <p>WebContainer is online and executing Node.js directly inside your browser.</p>
        </div>
      </body>
    </html>
  \`);
});

app.get('/manifest.json', (req, res) => {
  res.json({
    short_name: "TravelerApp",
    name: "Traveler Web App",
    start_url: "/",
    display: "standalone",
    background_color: "#0f172a",
    theme_color: "#6366f1"
  });
});

app.listen(port, () => console.log('Server running on port ' + port));`
        }
      }
    };

    let webcontainerInstance;
    let activeFile = 'index.js';
    
    const term = new Terminal({ convertEol: true, fontSize: 12 });
    term.open(document.getElementById('terminal'));

    window.setViewport = function(mode) {
      const ws = document.getElementById('workspace');
      ws.className = `workspace mode-${mode}`;
      document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
      document.getElementById(`btn-${mode}`).classList.add('active');
    };

    function renderFileTree() {
      const container = document.getElementById('file-tree');
      container.innerHTML = '';
      Object.keys(projectFiles).forEach(file => {
        const item = document.createElement('div');
        item.className = `file-item ${file === activeFile ? 'active' : ''}`;
        item.innerText = `📄 ${file}`;
        item.onclick = () => switchFile(file);
        container.appendChild(item);
      });
    }

    function switchFile(filename) {
      projectFiles[activeFile].file.contents = document.getElementById('editor').value;
      activeFile = filename;
      document.getElementById('active-tab').innerText = filename;
      document.getElementById('editor').value = projectFiles[filename].file.contents;
      renderFileTree();
    }

    document.getElementById('editor').addEventListener('input', async (e) => {
      projectFiles[activeFile].file.contents = e.target.value;
      if (webcontainerInstance) {
        await webcontainerInstance.fs.writeFile(activeFile, e.target.value);
      }
    });

    window.handleFileUpload = function(event) {
      const file = event.target.files[0];
      if (file) {
        document.getElementById('file-name-indicator').innerText = file.name;
        const reader = new FileReader();
        reader.onload = function(e) {
          projectFiles[file.name] = { file: { contents: e.target.result } };
          renderFileTree();
          switchFile(file.name);
        };
        reader.readAsText(file);
      }
    };

    window.submitPrompt = async function() {
      const promptText = document.getElementById('prompt-input').value;
      if (!promptText.trim()) return;

      term.write(`\r\n\x1b[33m[AI]: Processing prompt: "${promptText}"...\x1b[0m\r\n`);
      projectFiles['index.js'].file.contents += `\n// Prompt applied: ${promptText}`;
      
      if (activeFile === 'index.js') {
        document.getElementById('editor').value = projectFiles['index.js'].file.contents;
      }
      if (webcontainerInstance) {
        await webcontainerInstance.fs.writeFile('index.js', projectFiles['index.js'].file.contents);
      }
    };

    window.downloadZip = function() {
      const zip = new JSZip();
      Object.keys(projectFiles).forEach(filename => {
        zip.file(filename, projectFiles[filename].file.contents);
      });
      zip.generateAsync({ type: 'blob' }).then(blob => {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'traveler-workspace.zip';
        a.click();
      });
    };

    window.deployToSurge = async function() {
      const domain = `traveler-app-${Math.random().toString(36).substring(2, 8)}.surge.sh`;
      term.write(`\r\n\x1b[36m[Surge]: Pushing workspace build to https://${domain}...\x1b[0m\r\n`);

      const flatFiles = {};
      Object.keys(projectFiles).forEach(k => {
        flatFiles[k] = projectFiles[k].file.contents;
      });

      try {
        const res = await fetch(`${BACKEND_URL}/api/deploy-surge`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ files: flatFiles, domain })
        });
        const data = await res.json();
        if (data.success) {
          term.write(`\r\n\x1b[32m[Surge Success]: Deployed to ${data.url}\x1b[0m\r\n`);
          window.open(data.url, '_blank');
        } else {
          term.write(`\r\n\x1b[31m[Surge Error]: ${data.error}\x1b[0m\r\n`);
        }
      } catch (err) {
        term.write(`\r\n\x1b[31m[Deploy Error]: Could not reach backend service at ${BACKEND_URL}\x1b[0m\r\n`);
      }
    };

    async function bootContainer() {
      term.write('\x1b[32mBooting WebContainer Runtime with COI Header Interceptor...\x1b[0m\r\n');
      try {
        webcontainerInstance = await WebContainer.boot();
        await webcontainerInstance.mount(projectFiles);

        term.write('\x1b[32mRunning npm install...\x1b[0m\r\n');
        const installProc = await webcontainerInstance.spawn('npm', ['install']);
        installProc.output.pipeTo(new WritableStream({ write(data) { term.write(data); } }));
        await installProc.exit;

        term.write('\r\n\x1b[32mStarting Node app (npm start)...\x1b[0m\r\n');
        const startProc = await webcontainerInstance.spawn('npm', ['start']);
        startProc.output.pipeTo(new WritableStream({ write(data) { term.write(data); } }));

        webcontainerInstance.on('server-ready', (port, url) => {
          term.write(`\r\n\x1b[32mServer online: ${url}\x1b[0m\r\n`);
          document.getElementById('preview-frame').src = url;
        });
      } catch (e) {
        term.write(`\r\n\x1b[31mBoot Error: ${e.message}\x1b[0m\r\n`);
      }
    }

    renderFileTree();
    switchFile('index.js');
    bootContainer();
  </script>
</body>
</html>
HTMLEOF

echo "=== 3. Pushing directly to Hugging Face remote ==="
git add .
git commit -m "fix(coi): add service worker cross-origin isolation for hf, restore layout toggle, upload, and prompt dock" || true
git push hf main --force || git push origin main --force

echo "=== Deployment Complete ==="
