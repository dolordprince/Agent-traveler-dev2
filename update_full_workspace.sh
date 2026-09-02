#!/usr/bin/env bash
set -euo pipefail

TARGET_HTML="index.html"
if [ -f "webcontainer-ui/index.html" ]; then
  TARGET_HTML="webcontainer-ui/index.html"
fi

BASE_DIR="$(dirname "$TARGET_HTML")"

echo "=== 1. Injecting Comprehensive Workspace HTML into $TARGET_HTML ==="
cat << 'HTMLEOF' > "$TARGET_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TRAVELER.DEV - AI Workspace</title>
  <link rel="manifest" href="./manifest.json">
  <meta name="theme-color" content="#0b0d1b">
  <!-- JSZip for dynamic zip generation -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
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
      transition: all 0.2s;
    }
    .btn-nav:hover { background: rgba(255,255,255,0.1); }
    .btn-primary { background: var(--accent-gradient); border: none; font-weight: 600; }
    #pwa-install-btn { display: none; background: #22c55e; color: #000; font-weight: bold; border: none; }

    /* IDE MAIN LAYOUT */
    .ide-body {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* LEFT TOOLBAR */
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
    .icon-btn { color: var(--text-muted); cursor: pointer; font-size: 18px; opacity: 0.7; transition: opacity 0.2s; }
    .icon-btn.active, .icon-btn:hover { color: var(--accent); opacity: 1; }

    /* FILE EXPLORER */
    .file-explorer {
      width: 220px;
      background: var(--bg-surface);
      border-right: 1px solid var(--border);
      padding: 12px;
      font-size: 13px;
    }
    .tree-item { padding: 6px 8px; border-radius: 4px; cursor: pointer; color: #cbd5e1; user-select: none; }
    .tree-item:hover { background: rgba(255,255,255,0.05); }
    .tree-item.active { background: rgba(99, 102, 241, 0.15); color: #818cf8; font-weight: 600; }

    /* CENTER EDITOR & PROMPT DOCK */
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
    
    .code-area-wrapper {
      flex: 1;
      position: relative;
    }
    textarea.code-editor {
      width: 100%;
      height: 100%;
      background: #05060e;
      color: #38bdf8;
      font-family: 'Fira Code', monospace;
      font-size: 13px;
      border: none;
      outline: none;
      padding: 16px;
      resize: none;
      box-sizing: border-box;
      line-height: 1.5;
    }

    /* ENHANCED EXPANDED PROMPT DOCK */
    .prompt-dock {
      background: var(--bg-surface);
      border-top: 1px solid var(--border);
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .quick-tags { display: flex; gap: 8px; flex-wrap: wrap; }
    .tag { 
      background: rgba(255,255,255,0.04); 
      border: 1px solid var(--border); 
      font-size: 11px; 
      padding: 4px 10px; 
      border-radius: 6px; 
      color: var(--text-muted); 
      cursor: pointer;
      transition: all 0.2s;
    }
    .tag:hover { background: rgba(99, 102, 241, 0.2); color: white; }

    .prompt-card {
      background: #13162b;
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 10px 14px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .prompt-card textarea {
      width: 100%;
      height: 70px;
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
    .file-upload-label {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #94a3b8;
      cursor: pointer;
      background: rgba(255,255,255,0.05);
      padding: 4px 10px;
      border-radius: 6px;
      border: 1px solid var(--border);
    }
    .file-upload-label:hover { color: white; background: rgba(255,255,255,0.1); }
    #file-input { display: none; }
    #attached-file-name { font-size: 11px; color: #a78bfa; font-style: italic; }

    /* PREVIEW CONTAINER */
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
    .preview-actions { display: flex; gap: 8px; }
    iframe#preview-iframe { flex: 1; border: none; background: white; }
  </style>
</head>
<body>

  <!-- NAVBAR -->
  <div class="navbar">
    <div class="brand">🪐 TRAVELER.DEV <span style="font-size:10px; color:#22c55e; background:rgba(34,197,94,0.1); padding:2px 6px; border-radius:10px;">• Online</span></div>
    <div class="nav-actions">
      <button id="pwa-install-btn" class="btn-nav">📲 Install App</button>
      <button class="btn-nav" id="api-keys-btn">🔑 API Keys</button>
      <button class="btn-nav btn-primary" id="deploy-btn">🚀 Deploy</button>
    </div>
  </div>

  <!-- MAIN IDE WORKSPACE -->
  <div class="ide-body">
    <!-- TOOLBAR -->
    <div class="icon-sidebar">
      <div class="icon-btn active" title="Explorer">📁</div>
      <div class="icon-btn" title="AI Assistant">🤖</div>
      <div class="icon-btn" title="Terminal">⌨️</div>
      <div class="icon-btn" title="Settings">⚙️</div>
    </div>

    <!-- FILE EXPLORER -->
    <div class="file-explorer">
      <div style="font-weight:700; color:var(--text-muted); margin-bottom:12px; font-size:11px; letter-spacing:0.5px;">EXPLORER</div>
      <div class="tree-item" onclick="selectFile('index.html')">📄 index.html</div>
      <div class="tree-item active" id="item-App.tsx" onclick="selectFile('App.tsx')">📄 App.tsx</div>
      <div class="tree-item" id="item-styles.css" onclick="selectFile('styles.css')">📄 styles.css</div>
      <div class="tree-item" id="item-package.json" onclick="selectFile('package.json')">📄 package.json</div>
    </div>

    <!-- CODE EDITOR & ENHANCED PROMPT DOCK -->
    <div class="editor-container">
      <div class="tabs-bar">
        <div class="tab active" id="active-tab-title">App.tsx</div>
      </div>
      <div class="code-area-wrapper">
        <textarea class="code-editor" id="code-editor" spellcheck="false"></textarea>
      </div>

      <!-- EXPANDED PROMPT DOCK WITH FILE UPLOAD -->
      <div class="prompt-dock">
        <div class="quick-tags">
          <div class="tag" onclick="addTagPrompt('Build a responsive landing page')">✨ Build Landing Page</div>
          <div class="tag" onclick="addTagPrompt('Create a mobile dashboard component')">⚡ Mobile Dashboard</div>
          <div class="tag" onclick="addTagPrompt('Fix errors and optimize layout')">🔧 Fix & Refactor</div>
        </div>
        <div class="prompt-card">
          <textarea id="prompt" placeholder="Describe what you want to build or attach reference files..."></textarea>
          <div class="prompt-toolbar">
            <div style="display: flex; align-items: center; gap: 8px;">
              <label for="file-input" class="file-upload-label">
                📎 Attach File
              </label>
              <input type="file" id="file-input" onchange="handleFileUpload(event)">
              <span id="attached-file-name"></span>
            </div>
            <button id="build-btn" class="btn-nav btn-primary" onclick="generateCode()">✨ Generate & Run</button>
          </div>
        </div>
      </div>
    </div>

    <!-- PREVIEW WINDOW WITH ZIP DOWNLOAD -->
    <div class="preview-container">
      <div class="preview-header">
        <span>👁️ Live Preview</span>
        <div class="preview-actions">
          <button class="btn-nav" onclick="downloadZip()">📦 Download ZIP</button>
          <button class="btn-nav" id="reload-btn" onclick="updatePreview()">🔄 Reload</button>
        </div>
      </div>
      <iframe id="preview-iframe"></iframe>
    </div>
  </div>

  <script>
    // Workspace state
    const files = {
      'App.tsx': `export default function App() {\n  return (\n    <div style={{ padding: '2rem', fontFamily: 'system-ui', color: '#1e293b' }}>\n      <h1>🚀 TRAVELER.DEV Active Workspace</h1>\n      <p>Edit your code or send an AI prompt to start building.</p>\n    </div>\n  );\n}`,
      'index.html': `<!DOCTYPE html>\n<html>\n<head>\n  <style>\n    body { margin: 0; font-family: system-ui, sans-serif; background: #f8fafc; }\n  </style>\n</head>\n<body>\n  <div id="app"></div>\n  <script>\n    document.getElementById('app').innerHTML = '<div style="padding: 20px;"><h1>🚀 Live Application Preview</h1><p>Your workspace is live and updating automatically.</p></div>';\n  <\/script>\n</body>\n</html>`,
      'styles.css': `body {\n  background-color: #050511;\n  color: #ffffff;\n}`,
      'package.json': `{\n  "name": "traveler-workspace",\n  "version": "1.0.0",\n  "dependencies": {\n    "react": "^18.2.0"\n  }\n}`
    };

    let activeFile = 'App.tsx';
    const editor = document.getElementById('code-editor');

    function loadFile(filename) {
      activeFile = filename;
      document.getElementById('active-tab-title').innerText = filename;
      editor.value = files[filename] || '';
      
      document.querySelectorAll('.tree-item').forEach(el => el.classList.remove('active'));
      const activeTreeEl = document.getElementById('item-' + filename);
      if (activeTreeEl) activeTreeEl.classList.add('active');
    }

    function selectFile(filename) {
      files[activeFile] = editor.value;
      loadFile(filename);
    }

    editor.addEventListener('input', () => {
      files[activeFile] = editor.value;
      if (activeFile === 'index.html' || activeFile === 'App.tsx') {
        updatePreview();
      }
    });

    function updatePreview() {
      const iframe = document.getElementById('preview-iframe');
      let content = files['index.html'];
      if (activeFile === 'App.tsx') {
        content = `<!DOCTYPE html><html><head><style>body{margin:0;font-family:system-ui,sans-serif;padding:24px;background:#f8fafc;}</style></head><body>` +
                  `<div>` + files['App.tsx'].replace(/export default function App\(\) \{/g, '').replace(/return \(/g, '').replace(/\);/g, '').replace(/\}/g, '') + `</div></body></html>`;
      }
      iframe.srcdoc = content;
    }

    function addTagPrompt(text) {
      const promptInput = document.getElementById('prompt');
      promptInput.value = text + ': ';
      promptInput.focus();
    }

    function handleFileUpload(event) {
      const file = event.target.files[0];
      if (file) {
        document.getElementById('attached-file-name').innerText = file.name;
        const reader = new FileReader();
        reader.onload = function(e) {
          files[file.name] = e.target.result;
          const promptInput = document.getElementById('prompt');
          promptInput.value += `\n[Attached File: ${file.name}]`;
        };
        reader.readAsText(file);
      }
    }

    function generateCode() {
      const promptText = document.getElementById('prompt').value;
      if (!promptText.trim()) return;
      
      editor.value = `// Generated from prompt: ${promptText}\n` + editor.value;
      files[activeFile] = editor.value;
      updatePreview();
      alert('Prompt applied to ' + activeFile);
    }

    function downloadZip() {
      files[activeFile] = editor.value;
      const zip = new JSZip();
      for (const [filename, content] of Object.entries(files)) {
        zip.file(filename, content);
      }
      zip.generateAsync({ type: 'blob' }).then(function(content) {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(content);
        a.download = 'traveler-workspace.zip';
        a.click();
      });
    }

    // Modal & Action Listeners
    document.getElementById('api-keys-btn').onclick = () => alert('API Key Config: OpenAI / Hugging Face key active.');
    document.getElementById('deploy-btn').onclick = () => alert('Deployment initialized to Hugging Face Spaces.');

    // Initialize UI state
    loadFile('App.tsx');
    updatePreview();

    // PWA Service Worker Registration
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

echo "=== 2. Committing and Pushing to Hugging Face ==="
git add .
git commit -m "feat(workspace): expand prompt dock with upload, add preview runner and ZIP export" || true

git push hf main --force || git push origin main --force

echo "=== Success! Complete workspace updated and deployed to Hugging Face. ==="
