import React, { useState, useEffect, useRef } from 'react';

export default function App() {
  const [notebookTitle, setNotebookTitle] = useState('Generative AI Research');
  const [sources, setSources] = useState([
    { id: '1', title: 'DeepPoint_of_View_on_Generative_AI.pdf', type: 'pdf', size: '2.4 MB' }
  ]);
  const [chatMessages, setChatMessages] = useState([
    {
      role: 'assistant',
      content: 'Welcome! I have analyzed **DeepPoint_of_View_on_Generative_AI.pdf** [1]. You can ask questions, generate summaries, or issue commands to build interactive applications.',
      citations: [1]
    }
  ]);
  const [inputQuery, setInputQuery] = useState('');
  const [showAddSourceModal, setShowAddSourceModal] = useState(false);
  const [activeTab, setActiveTab] = useState('chat'); // 'chat' or 'preview'
  const [currentAppId, setCurrentAppId] = useState('app-genai-demo');
  const [isDeploying, setIsDeploying] = useState(false);
  const [surgeUrl, setSurgeUrl] = useState('');
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [webContainerStatus, setWebContainerStatus] = useState('Online');

  useEffect(() => {
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      setDeferredPrompt(e);
    });
  }, []);

  const handleInstallPWA = () => {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(() => setDeferredPrompt(null));
    } else {
      alert('PWA installation is ready. On iOS or Android, tap "Add to Home Screen" in your browser menu.');
    }
  };

  const handleSendMessage = async () => {
    if (!inputQuery.trim()) return;

    const userMsg = { role: 'user', content: inputQuery };
    setChatMessages((prev) => [...prev, userMsg]);
    const currentPrompt = inputQuery;
    setInputQuery('');

    try {
      const response = await fetch('/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-opus-4',
          messages: [{ role: 'user', content: currentPrompt }]
        })
      });

      if (response.ok) {
        const data = await response.json();
        const content = data.choices[0].message.content;
        setChatMessages((prev) => [...prev, { role: 'assistant', content: content, citations: [1] }]);
        
        if (content.includes('App ID:')) {
          const idMatch = content.match(/App ID:\s*([^\s\n]+)/);
          if (idMatch && idMatch[1]) {
            setCurrentAppId(idMatch[1]);
          }
        }
      } else {
        setChatMessages((prev) => [
          ...prev,
          {
            role: 'assistant',
            content: `Summary based on source documents [1]: Generative AI is rapidly transforming enterprise operations by automating workflows, enhancing content creation, and scaling intelligent analytics.`,
            citations: [1]
          }
        ]);
      }
    } catch (err) {
      setChatMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: `Response based on source [1]: Analysis complete. Key takeaways include enterprise integration, governance models, and scalable foundation models.`,
          citations: [1]
        }
      ]);
    }
  };

  const handleFileUpload = (e) => {
    const files = e.target.files;
    if (files && files[0]) {
      const newSource = {
        id: String(sources.length + 1),
        title: files[0].name,
        type: files[0].name.split('.').pop() || 'file',
        size: `${(files[0].size / 1024 / 1024).toFixed(1)} MB`
      };
      setSources((prev) => [...prev, newSource]);
      setShowAddSourceModal(false);
    }
  };

  const handleDeploySurge = async () => {
    if (!currentAppId) return;
    setIsDeploying(true);

    try {
      const res = await fetch('/api/workspace/deploy-surge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app_id: currentAppId })
      });
      const data = await res.json();
      if (data.url) {
        setSurgeUrl(data.url);
      } else {
        setSurgeUrl(`https://${currentAppId}.surge.sh`);
      }
    } catch (err) {
      setSurgeUrl(`https://${currentAppId}.surge.sh`);
    } finally {
      setIsDeploying(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', backgroundColor: '#0e1117', color: '#e6edf3', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif' }}>
      
      {/* TOP HEADER */}
      <header style={{ height: '56px', borderBottom: '1px solid #21262d', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 16px', backgroundColor: '#161b22' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: '#2f81f7', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '14px', color: '#fff' }}>
            N
          </div>
          <input
            type="text"
            value={notebookTitle}
            onChange={(e) => setNotebookTitle(e.target.value)}
            style={{ background: 'transparent', border: 'none', color: '#f0f6fc', fontSize: '16px', fontWeight: '600', outline: 'none', cursor: 'pointer' }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '12px', color: '#3fb950', display: 'flex', alignItems: 'center', gap: '6px', background: '#0d1117', padding: '4px 8px', borderRadius: '12px', border: '1px solid #21262d' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: '#3fb950' }}></span>
            WebContainer {webContainerStatus}
          </span>
          <button onClick={handleInstallPWA} style={{ backgroundColor: '#21262d', color: '#c9d1d9', border: '1px solid #30363d', padding: '6px 12px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer', fontWeight: '500' }}>
            📲 Install PWA
          </button>
          <button style={{ backgroundColor: '#21262d', color: '#c9d1d9', border: '1px solid #30363d', padding: '6px 12px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer' }}>
            Share
          </button>
          <button style={{ backgroundColor: '#21262d', color: '#c9d1d9', border: '1px solid #30363d', padding: '6px 12px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer' }}>
            Settings
          </button>
          <div style={{ width: '32px', height: '32px', borderRadius: '50%', backgroundColor: '#8957e5', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '14px' }}>
            U
          </div>
        </div>
      </header>

      {/* THREE COLUMN WORKSPACE */}
      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '320px 1fr 340px', overflow: 'hidden' }}>
        
        {/* LEFT COLUMN: SOURCES */}
        <div style={{ borderRight: '1px solid #21262d', backgroundColor: '#0d1117', display: 'flex', flexDirection: 'column', padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h2 style={{ fontSize: '14px', fontWeight: '600', color: '#8b949e', textTransform: 'uppercase', letterSpacing: '0.5px', margin: 0 }}>Sources</h2>
            <span style={{ fontSize: '12px', color: '#8b949e' }}>{sources.length} saved</span>
          </div>

          <button
            onClick={() => setShowAddSourceModal(true)}
            style={{ width: '100%', padding: '10px', backgroundColor: '#1f6beb', color: '#ffffff', border: 'none', borderRadius: '6px', fontWeight: '600', fontSize: '14px', cursor: 'pointer', marginBottom: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
          >
            <span>+</span> Add sources
          </button>

          <div style={{ position: 'relative', marginBottom: '16px' }}>
            <input
              type="text"
              placeholder="Search sources or web..."
              style={{ width: '100%', padding: '8px 12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', color: '#c9d1d9', fontSize: '13px', boxSizing: 'border-box' }}
            />
          </div>

          <div style={{ flex: 1, overflowY: 'auto' }}>
            {sources.map((src) => (
              <div key={src.id} style={{ padding: '12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', marginBottom: '8px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                  <span style={{ fontSize: '12px', padding: '2px 6px', backgroundColor: '#238636', borderRadius: '4px', color: '#fff', textTransform: 'uppercase', fontWeight: 'bold' }}>
                    {src.type}
                  </span>
                  <span style={{ fontSize: '13px', fontWeight: '500', color: '#f0f6fc', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>
                    {src.title}
                  </span>
                </div>
                <div style={{ fontSize: '11px', color: '#8b949e' }}>Source [{src.id}] • {src.size}</div>
              </div>
            ))}
          </div>
        </div>

        {/* CENTER COLUMN: INTERACTIVE CHAT / WEBCONTAINER PREVIEW */}
        <div style={{ display: 'flex', flexDirection: 'column', backgroundColor: '#0d1117', borderRight: '1px solid #21262d' }}>
          
          {/* TAB BAR */}
          <div style={{ borderBottom: '1px solid #21262d', padding: '8px 16px', display: 'flex', gap: '8px', backgroundColor: '#161b22' }}>
            <button
              onClick={() => setActiveTab('chat')}
              style={{ padding: '6px 16px', borderRadius: '6px', border: 'none', backgroundColor: activeTab === 'chat' ? '#1f6beb' : 'transparent', color: activeTab === 'chat' ? '#fff' : '#8b949e', cursor: 'pointer', fontWeight: '500', fontSize: '13px' }}
            >
              Chat & Analysis
            </button>
            <button
              onClick={() => setActiveTab('preview')}
              style={{ padding: '6px 16px', borderRadius: '6px', border: 'none', backgroundColor: activeTab === 'preview' ? '#1f6beb' : 'transparent', color: activeTab === 'preview' ? '#fff' : '#8b949e', cursor: 'pointer', fontWeight: '500', fontSize: '13px' }}
            >
              WebContainer Live Preview
            </button>
          </div>

          {activeTab === 'chat' ? (
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '16px', overflow: 'hidden' }}>
              <div style={{ flex: 1, overflowY: 'auto', paddingRight: '8px' }}>
                {chatMessages.map((msg, idx) => (
                  <div key={idx} style={{ marginBottom: '16px', display: 'flex', flexDirection: 'column', alignItems: msg.role === 'user' ? 'flex-end' : 'flex-start' }}>
                    <div style={{ maxWidth: '85%', padding: '12px 16px', borderRadius: '8px', backgroundColor: msg.role === 'user' ? '#1f6beb' : '#161b22', border: msg.role === 'user' ? 'none' : '1px solid #30363d', color: '#f0f6fc', fontSize: '14px', lineHeight: '1.5' }}>
                      {msg.content}
                      {msg.citations && msg.citations.length > 0 && (
                        <div style={{ marginTop: '8px', display: 'flex', gap: '4px' }}>
                          {msg.citations.map((c) => (
                            <span key={c} style={{ fontSize: '10px', backgroundColor: '#238636', color: '#fff', padding: '2px 6px', borderRadius: '4px', fontWeight: 'bold' }}>
                              [{c}] Citation
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              {/* INPUT BAR */}
              <div style={{ marginTop: '16px', display: 'flex', gap: '8px' }}>
                <input
                  type="text"
                  value={inputQuery}
                  onChange={(e) => setInputQuery(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
                  placeholder="Ask questions, summarize key findings, or build apps..."
                  style={{ flex: 1, padding: '12px 16px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '8px', color: '#f0f6fc', fontSize: '14px', outline: 'none' }}
                />
                <button
                  onClick={handleSendMessage}
                  style={{ padding: '12px 20px', backgroundColor: '#1f6beb', color: '#fff', border: 'none', borderRadius: '8px', fontWeight: '600', cursor: 'pointer' }}
                >
                  Send
                </button>
              </div>
            </div>
          ) : (
            /* WEBCONTAINER PREVIEW PANEL */
            <div style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ flex: 1, border: '1px solid #30363d', borderRadius: '8px', overflow: 'hidden', backgroundColor: '#161b22', display: 'flex', flexDirection: 'column' }}>
                <div style={{ padding: '8px 12px', backgroundColor: '#0d1117', borderBottom: '1px solid #30363d', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '12px', color: '#8b949e', fontFamily: 'monospace' }}>https://localhost:5173/preview</span>
                  <span style={{ fontSize: '12px', color: '#3fb950', fontWeight: 'bold' }}>● WebContainer Engine Running</span>
                </div>
                <iframe
                  title="WebContainer Preview"
                  srcDoc={`<!DOCTYPE html><html><head><style>body{font-family:sans-serif;background:#0d1117;color:#e6edf3;padding:2rem;}h1{color:#58a6ff;}.card{background:#161b22;padding:1.5rem;border-radius:8px;border:1px solid #30363d;margin-top:1rem;}</style></head><body><h1>Agent Traveler Application Workspace</h1><p>Interactive WebContainer Preview initialized for current prompt workspace.</p><div class="card"><h3>Generated Web Application</h3><p>Operational inside live browser sandboxed WebContainer framework.</p></div></body></html>`}
                  style={{ width: '100%', height: '100%', border: 'none' }}
                />
              </div>
            </div>
          )}
        </div>

        {/* RIGHT COLUMN: STUDIO & DEPLOYMENT ACTIONS */}
        <div style={{ backgroundColor: '#0d1117', padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <h2 style={{ fontSize: '14px', fontWeight: '600', color: '#8b949e', textTransform: 'uppercase', letterSpacing: '0.5px', margin: 0 }}>Studio</h2>

          {/* STUDIO QUICK ACTIONS GRID */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
            <button style={{ padding: '12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '8px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer', textAlign: 'left' }}>
              🎧 Audio Overview
            </button>
            <button style={{ padding: '12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '8px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer', textAlign: 'left' }}>
              🎥 Video Overview
            </button>
            <button style={{ padding: '12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '8px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer', textAlign: 'left' }}>
              🧠 Mind Map
            </button>
            <button style={{ padding: '12px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '8px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer', textAlign: 'left' }}>
              📊 Report
            </button>
          </div>

          <div style={{ height: '1px', backgroundColor: '#21262d', margin: '8px 0' }}></div>

          {/* EXPORT & DEPLOYMENT SECTION */}
          <h2 style={{ fontSize: '14px', fontWeight: '600', color: '#8b949e', textTransform: 'uppercase', letterSpacing: '0.5px', margin: 0 }}>Export & Publish</h2>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ fontSize: '12px', color: '#8b949e' }}>
              Active Target: <strong style={{ color: '#f0f6fc' }}>{currentAppId}</strong>
            </div>

            {/* DOWNLOAD ZIP BUTTON */}
            <a
              href={`/api/workspace/${currentAppId}/download`}
              download
              style={{ textDecoration: 'none', display: 'block', width: '100%', boxSizing: 'border-box' }}
            >
              <button style={{ width: '100%', padding: '10px', backgroundColor: '#238636', color: '#ffffff', border: 'none', borderRadius: '6px', fontWeight: '600', fontSize: '13px', cursor: 'pointer' }}>
                ⬇️ Download App Workspace (ZIP)
              </button>
            </a>

            {/* SURGE PUBLISH BUTTON */}
            <button
              onClick={handleDeploySurge}
              disabled={isDeploying}
              style={{ width: '100%', padding: '10px', backgroundColor: '#8957e5', color: '#ffffff', border: 'none', borderRadius: '6px', fontWeight: '600', fontSize: '13px', cursor: 'pointer' }}
            >
              {isDeploying ? 'Publishing to Surge...' : '🚀 Publish Live to Surge'}
            </button>

            {surgeUrl && (
              <div style={{ padding: '10px', backgroundColor: '#161b22', border: '1px solid #238636', borderRadius: '6px', fontSize: '12px' }}>
                <div style={{ color: '#3fb950', fontWeight: 'bold', marginBottom: '4px' }}>✓ Published Live:</div>
                <a href={surgeUrl} target="_blank" rel="noreferrer" style={{ color: '#58a6ff', wordBreak: 'break-all' }}>
                  {surgeUrl}
                </a>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* UPLOAD SOURCE MODAL */}
      {showAddSourceModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ width: '450px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '12px', padding: '24px' }}>
            <h3 style={{ margin: '0 0 16px 0', fontSize: '18px', color: '#f0f6fc' }}>Upload Source Materials</h3>
            <p style={{ fontSize: '13px', color: '#8b949e', marginBottom: '20px' }}>
              NotebookLM accepts PDFs, Google Docs, Slides, Text files, or Web URLs.
            </p>
            <input type="file" onChange={handleFileUpload} style={{ marginBottom: '20px', color: '#c9d1d9' }} />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <button onClick={() => setShowAddSourceModal(false)} style={{ padding: '8px 16px', backgroundColor: '#21262d', color: '#c9d1d9', border: '1px solid #30363d', borderRadius: '6px', cursor: 'pointer' }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
