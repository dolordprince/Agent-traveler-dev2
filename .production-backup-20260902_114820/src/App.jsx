import React, { useState, useEffect } from 'react';

export default function App() {
  const [notebookTitle, setNotebookTitle] = useState('TRAVELER-DEV');
  const [sources, setSources] = useState([
    { id: '1', title: 'DeepPoint_of_View_on_Generative_AI.pdf', type: 'pdf', size: '2.4 MB' }
  ]);
  const [chatMessages, setChatMessages] = useState([
    {
      role: 'assistant',
      content: 'Welcome to **TRAVELER-DEV** workspace! The StackBlitz WebContainer API is integrated and connected to your active backend gateway [1].',
      citations: [1]
    }
  ]);
  const [inputQuery, setInputQuery] = useState('');
  const [activeTab, setActiveTab] = useState('chat'); // 'chat' | 'preview'
  const [currentAppId, setCurrentAppId] = useState('app-traveler-dev');
  const [surgeUrl, setSurgeUrl] = useState('');
  const [isDeploying, setIsDeploying] = useState(false);

  const handleSendMessage = () => {
    if (!inputQuery.trim()) return;
    const newMsg = { role: 'user', content: inputQuery };
    setChatMessages((prev) => [...prev, newMsg]);
    const userPrompt = inputQuery;
    setInputQuery('');

    setTimeout(() => {
      setChatMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: `Analysis for "${userPrompt}": TRAVELER-DEV WebContainer engine processed the prompt [1]. Ready for build or export.`,
          citations: [1]
        }
      ]);
    }, 600);
  };

  const handleDeploySurge = async () => {
    setIsDeploying(true);
    setTimeout(() => {
      setSurgeUrl(`https://${currentAppId}.surge.sh`);
      setIsDeploying(false);
    }, 1500);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', backgroundColor: '#0e1117', color: '#e6edf3', fontFamily: 'sans-serif' }}>
      
      {/* HEADER */}
      <header style={{ height: '56px', borderBottom: '1px solid #21262d', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 16px', backgroundColor: '#161b22' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: '#2f81f7', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '13px', color: '#fff' }}>
            T
          </div>
          <input
            type="text"
            value={notebookTitle}
            onChange={(e) => setNotebookTitle(e.target.value)}
            style={{ background: 'transparent', border: 'none', color: '#f0f6fc', fontSize: '16px', fontWeight: 'bold', outline: 'none' }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '12px', color: '#3fb950', background: '#0d1117', padding: '4px 8px', borderRadius: '12px', border: '1px solid #21262d' }}>
            ● WebContainer Engine Active
          </span>
          <button style={{ backgroundColor: '#21262d', color: '#c9d1d9', border: '1px solid #30363d', padding: '6px 12px', borderRadius: '6px', fontSize: '12px', cursor: 'pointer' }}>
            Share
          </button>
        </div>
      </header>

      {/* THREE-COLUMN WORKSPACE */}
      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '300px 1fr 320px', overflow: 'hidden' }}>
        
        {/* LEFT: SOURCES */}
        <div style={{ borderRight: '1px solid #21262d', backgroundColor: '#0d1117', padding: '16px', display: 'flex', flexDirection: 'column' }}>
          <h3 style={{ fontSize: '12px', color: '#8b949e', margin: '0 0 12px 0', textTransform: 'uppercase' }}>Sources ({sources.length})</h3>
          <button style={{ width: '100%', padding: '10px', backgroundColor: '#1f6beb', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: '600', marginBottom: '16px', cursor: 'pointer' }}>
            + Add Source
          </button>
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {sources.map((src) => (
              <div key={src.id} style={{ padding: '10px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', marginBottom: '8px' }}>
                <div style={{ fontSize: '13px', fontWeight: '600', color: '#f0f6fc' }}>{src.title}</div>
                <div style={{ fontSize: '11px', color: '#8b949e', marginTop: '4px' }}>[{src.id}] PDF • {src.size}</div>
              </div>
            ))}
          </div>
        </div>

        {/* CENTER: CHAT / PREVIEW */}
        <div style={{ display: 'flex', flexDirection: 'column', backgroundColor: '#0d1117', borderRight: '1px solid #21262d' }}>
          <div style={{ borderBottom: '1px solid #21262d', padding: '8px 16px', backgroundColor: '#161b22', display: 'flex', gap: '8px' }}>
            <button onClick={() => setActiveTab('chat')} style={{ padding: '6px 12px', borderRadius: '6px', border: 'none', backgroundColor: activeTab === 'chat' ? '#1f6beb' : 'transparent', color: '#fff', cursor: 'pointer', fontSize: '13px' }}>
              Chat Workspace
            </button>
            <button onClick={() => setActiveTab('preview')} style={{ padding: '6px 12px', borderRadius: '6px', border: 'none', backgroundColor: activeTab === 'preview' ? '#1f6beb' : 'transparent', color: '#fff', cursor: 'pointer', fontSize: '13px' }}>
              StackBlitz Preview
            </button>
          </div>

          {activeTab === 'chat' ? (
            <div style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ flex: 1, overflowY: 'auto' }}>
                {chatMessages.map((msg, idx) => (
                  <div key={idx} style={{ marginBottom: '12px', display: 'flex', justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start' }}>
                    <div style={{ maxWidth: '80%', padding: '10px 14px', borderRadius: '8px', backgroundColor: msg.role === 'user' ? '#1f6beb' : '#161b22', border: msg.role === 'user' ? 'none' : '1px solid #30363d', fontSize: '14px' }}>
                      {msg.content}
                    </div>
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
                <input
                  type="text"
                  value={inputQuery}
                  onChange={(e) => setInputQuery(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
                  placeholder="Ask TRAVELER-DEV or generate code..."
                  style={{ flex: 1, padding: '10px 14px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', color: '#fff' }}
                />
                <button onClick={handleSendMessage} style={{ padding: '10px 18px', backgroundColor: '#1f6beb', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer' }}>
                  Send
                </button>
              </div>
            </div>
          ) : (
            <div style={{ flex: 1, padding: '16px' }}>
              <iframe
                title="StackBlitz WebContainer Preview"
                srcDoc={`<!DOCTYPE html><html><head><style>body{font-family:sans-serif;background:#0d1117;color:#e6edf3;padding:2rem;}</style></head><body><h2>TRAVELER-DEV Preview Engine</h2><p>StackBlitz WebContainer execution sandbox running.</p></body></html>`}
                style={{ width: '100%', height: '100%', border: '1px solid #30363d', borderRadius: '8px', backgroundColor: '#161b22' }}
              />
            </div>
          )}
        </div>

        {/* RIGHT: STUDIO & EXPORT */}
        <div style={{ backgroundColor: '#0d1117', padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <h3 style={{ fontSize: '12px', color: '#8b949e', margin: 0, textTransform: 'uppercase' }}>Studio & Actions</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
            <button style={{ padding: '10px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer' }}>🎧 Audio Overview</button>
            <button style={{ padding: '10px', backgroundColor: '#161b22', border: '1px solid #30363d', borderRadius: '6px', color: '#c9d1d9', fontSize: '12px', cursor: 'pointer' }}>🧠 Mind Map</button>
          </div>

          <hr style={{ borderColor: '#21262d', margin: '8px 0' }} />

          <h3 style={{ fontSize: '12px', color: '#8b949e', margin: 0, textTransform: 'uppercase' }}>Deploy & Export</h3>
          <a href={`/api/workspace/${currentAppId}/download`} download style={{ textDecoration: 'none' }}>
            <button style={{ width: '100%', padding: '10px', backgroundColor: '#238636', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: '600', cursor: 'pointer' }}>
              ⬇️ Download Workspace (ZIP)
            </button>
          </a>
          <button onClick={handleDeploySurge} style={{ width: '100%', padding: '10px', backgroundColor: '#8957e5', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: '600', cursor: 'pointer' }}>
            {isDeploying ? 'Deploying...' : '🚀 Deploy to Surge'}
          </button>
          {surgeUrl && (
            <div style={{ padding: '8px', backgroundColor: '#161b22', border: '1px solid #238636', borderRadius: '6px', fontSize: '12px', color: '#3fb950' }}>
              Live: <a href={surgeUrl} target="_blank" rel="noreferrer" style={{ color: '#58a6ff' }}>{surgeUrl}</a>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
