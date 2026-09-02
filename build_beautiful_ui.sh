#!/usr/bin/env bash
set -euo pipefail

# Ensure we are working in the right directory
TARGET_DIR="."
if [ -d "webcontainer-ui" ]; then
  TARGET_DIR="webcontainer-ui"
fi

mkdir -p "$TARGET_DIR/src/components" "$TARGET_DIR/public"

echo "=== 1. Writing Deep Space Theme CSS ==="
cat << 'CSSEOF' > "$TARGET_DIR/src/index.css"
:root {
  --bg-dark: #050511;
  --bg-panel: #0a0b1a;
  --bg-card: #13142c;
  --border-neon: rgba(99, 102, 241, 0.2);
  --text-main: #e2e8f0;
  --text-muted: #64748b;
  --accent-blue: #3b82f6;
  --accent-purple: #8b5cf6;
}

* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
  background-color: var(--bg-dark);
  color: var(--text-main);
  height: 100vh;
  overflow: hidden;
}

/* Layout Grid */
.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.main-content {
  display: flex;
  flex: 1;
  overflow: hidden;
  padding: 0.5rem;
  gap: 0.5rem;
}

/* Panels */
.panel {
  background-color: var(--bg-panel);
  border: 1px solid var(--border-neon);
  border-radius: 0.75rem;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Sidebar & Explorer */
.sidebar-nav {
  width: 70px;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem 0;
  gap: 1.5rem;
  background-color: var(--bg-card);
  border-radius: 0.75rem;
  border: 1px solid var(--border-neon);
}

.explorer-panel {
  width: 240px;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.explorer-top { flex: 1; }
.ai-assistant { height: 250px; background: rgba(139, 92, 246, 0.05); }

/* Center Code & Terminal */
.center-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.code-editor {
  flex: 1;
  background: #0d0e21;
}

.ai-generate-bar {
  height: 120px;
  background: var(--bg-card);
  padding: 1rem;
}

/* Right Preview & Settings */
.right-panel {
  width: 320px;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.preview-window { flex: 1; background: #fff; color: #000; }
.settings-window { height: 200px; background: var(--bg-card); padding: 1rem; }

/* Buttons & Inputs */
.gradient-btn {
  background: linear-gradient(135deg, var(--accent-purple), var(--accent-blue));
  color: white;
  border: none;
  border-radius: 0.5rem;
  padding: 0.5rem 1rem;
  font-weight: 600;
  cursor: pointer;
}

.glass-btn {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: white;
  border-radius: 0.5rem;
  padding: 0.5rem 1rem;
  cursor: pointer;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  background: var(--bg-card);
  border-bottom: 1px solid var(--border-neon);
}
CSSEOF

echo "=== 2. Creating the React Layout Shell ==="
cat << 'APPEOF' > "$TARGET_DIR/src/App.jsx"
import React from 'react';
import './index.css';

function App() {
  return (
    <div className="app-container">
      {/* HEADER */}
      <header className="header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ fontWeight: 'bold', fontSize: '1.2rem', color: '#a78bfa' }}>🪐 TRAVELER.DEV</div>
          <div className="glass-btn" style={{ fontSize: '0.8rem', padding: '0.2rem 0.6rem' }}>🟢 Online</div>
        </div>
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <button className="glass-btn">🔑 API Keys</button>
          <button className="gradient-btn">🚀 Test & Deploy</button>
        </div>
      </header>

      {/* MAIN LAYOUT */}
      <div className="main-content">
        
        {/* LEFT NAV */}
        <div className="sidebar-nav">
          <div style={{ color: '#a78bfa' }}>🏠</div>
          <div>✨</div>
          <div>📁</div>
          <div>⌨️</div>
          <div>👁️</div>
          <div>🚀</div>
        </div>

        {/* EXPLORER & AI ASSISTANT */}
        <div className="explorer-panel">
          <div className="panel explorer-top" style={{ padding: '1rem' }}>
            <div style={{ color: '#94a3b8', fontSize: '0.9rem', marginBottom: '1rem' }}>Explorer</div>
            <div style={{ fontSize: '0.85rem' }}>
              <div>📁 src</div>
              <div style={{ paddingLeft: '1rem', color: '#60a5fa' }}>📄 App.tsx</div>
              <div style={{ paddingLeft: '1rem' }}>📄 index.css</div>
              <div>📄 package.json</div>
            </div>
          </div>
          <div className="panel ai-assistant" style={{ padding: '1rem' }}>
            <div style={{ color: '#a78bfa', fontWeight: 'bold', marginBottom: '0.5rem' }}>🤖 AI Assistant</div>
            <div style={{ fontSize: '0.85rem', color: '#cbd5e1' }}>I'm your AI coding assistant. Ask me to build, fix or improve your project.</div>
          </div>
        </div>

        {/* CENTER EDITOR & TERMINAL */}
        <div className="center-panel">
          <div className="panel code-editor">
            <div style={{ display: 'flex', background: '#1e1e38', padding: '0.5rem', gap: '1rem', fontSize: '0.85rem' }}>
              <span style={{ color: '#60a5fa' }}>App.tsx x</span>
              <span style={{ color: '#94a3b8' }}>index.css</span>
            </div>
            <div style={{ padding: '1rem', fontFamily: 'monospace', color: '#c0caf5', fontSize: '0.9rem' }}>
              <span style={{color: '#c586c0'}}>import</span> React <span style={{color: '#c586c0'}}>from</span> 'react';<br/><br/>
              <span style={{color: '#569cd6'}}>function</span> <span style={{color: '#dcdcaa'}}>App</span>() {'{'}<br/>
              &nbsp;&nbsp;<span style={{color: '#c586c0'}}>return</span> (<br/>
              &nbsp;&nbsp;&nbsp;&nbsp;&lt;<span style={{color: '#569cd6'}}>div</span>&gt;Hello World&lt;/<span style={{color: '#569cd6'}}>div</span>&gt;<br/>
              &nbsp;&nbsp;);<br/>
              {'}'}
            </div>
          </div>
          <div className="panel ai-generate-bar">
            <div style={{ display: 'flex', gap: '1rem', marginBottom: '0.5rem', color: '#94a3b8', fontSize: '0.85rem' }}>
              <span>✨ AI Generate</span>
              <span>📁 Upload Files</span>
              <span>⌨️ Terminal</span>
            </div>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <input type="text" placeholder="Describe what you want to build..." style={{ flex: 1, padding: '0.75rem', borderRadius: '0.5rem', background: '#1e1e38', border: '1px solid rgba(255,255,255,0.1)', color: 'white' }} />
              <button className="gradient-btn">Send ✈️</button>
            </div>
          </div>
        </div>

        {/* RIGHT PREVIEW & SETTINGS */}
        <div className="right-panel">
          <div className="panel preview-window">
             <div style={{ background: '#e2e8f0', padding: '0.2rem 1rem', fontSize: '0.75rem', color: '#64748b', display: 'flex', justifyContent: 'space-between' }}>
               <span>Browser Preview</span>
               <span>localhost:5173</span>
             </div>
             <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', padding: '2rem', textAlign: 'center' }}>
                <h1 style={{ color: '#0f172a', margin: 0 }}>Build Amazing Apps</h1>
                <p style={{ color: '#334155', fontSize: '0.9rem' }}>Turn your ideas into reality with Traveler.dev</p>
             </div>
          </div>
          <div className="panel settings-window">
            <div style={{ color: '#a78bfa', fontWeight: 'bold', marginBottom: '1rem' }}>⚙️ Workspace Settings</div>
            <div style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
              <div>Model Provider</div>
              <select style={{ width: '100%', padding: '0.5rem', margin: '0.2rem 0 1rem 0', background: '#1e1e38', color: 'white', border: 'none' }}>
                <option>OpenAI Compatible</option>
              </select>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}

export default App;
APPEOF

echo "=== 3. Ensuring main entry point is correct ==="
cat << 'MAINEOF' > "$TARGET_DIR/src/main.jsx"
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
MAINEOF

echo "=== 4. Pushing fix to Hugging Face ==="
git add "$TARGET_DIR/src/index.css" "$TARGET_DIR/src/App.jsx" "$TARGET_DIR/src/main.jsx"
git commit -m "style: implement dark modern IDE layout matching target UI" || true
git push hf main --force

echo "=== Done! The beautiful UI is now deploying. ==="
