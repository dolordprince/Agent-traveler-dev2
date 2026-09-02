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
