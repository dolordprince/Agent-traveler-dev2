import React, { useState, useEffect } from 'react';

export default function NotebookWorkspace() {
  const [sources, setSources] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [inputQuery, setInputQuery] = useState('');
  const [currentAppId, setCurrentAppId] = useState(null);
  const [surgeUrl, setSurgeUrl] = useState('');
  const [isDeploying, setIsDeploying] = useState(false);
  const [deferredPrompt, setDeferredPrompt] = useState(null);

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
    }
  };

  const handleSendMessage = async () => {
    if (!inputQuery.trim()) return;

    const userMsg = { role: 'user', content: inputQuery };
    setChatMessages((prev) => [...prev, userMsg]);
    setInputQuery('');

    try {
      const response = await fetch('/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-opus-4',
          messages: [...chatMessages, userMsg]
        })
      });
      
      const data = await response.json();
      const botResponse = data.choices[0].message.content;
      
      setChatMessages((prev) => [...prev, { role: 'assistant', content: botResponse }]);

      if (botResponse.includes('App ID: ')) {
        const extractedId = botResponse.split('App ID: ')[1].split('\n')[0].trim();
        setCurrentAppId(extractedId);
      }
    } catch (err) {
      setChatMessages((prev) => [...prev, { role: 'assistant', content: `Error: ${err.message}` }]);
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
      }
    } catch (err) {
      alert(`Surge Deployment Failed: ${err.message}`);
    } finally {
      setIsDeploying(false);
    }
  };

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '280px 1fr 320px', height: '100vh', background: '#0b0f19', color: '#e2e8f0', fontFamily: 'sans-serif' }}>
      
      {/* LEFT PANEL: Sources */}
      <div style={{ borderRight: '1px solid #1e293b', padding: '1rem', display: 'flex', flexDirection: 'column' }}>
        <h3 style={{ fontSize: '0.9rem', color: '#94a3b8', textTransform: 'uppercase' }}>Sources</h3>
        <button style={{ background: '#1e293b', border: '1px solid #334155', color: '#fff', padding: '0.5rem', borderRadius: '6px', cursor: 'pointer', margin: '0.5rem 0 1rem' }}>
          + Add Source
        </button>
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {sources.length === 0 ? (
            <p style={{ fontSize: '0.8rem', color: '#64748b' }}>No sources added yet. Upload documents or enter links.</p>
          ) : (
            sources.map((s, idx) => <div key={idx} style={{ padding: '0.5rem', background: '#1e293b', marginBottom: '0.5rem', borderRadius: '4px' }}>{s.name}</div>)
          )}
        </div>
        {deferredPrompt && (
          <button onClick={handleInstallPWA} style={{ background: '#2563eb', color: '#fff', border: 'none', padding: '0.6rem', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
            📲 Install PWA App
          </button>
        )}
      </div>

      {/* CENTER PANEL: Interactive Chat */}
      <div style={{ display: 'flex', flexDirection: 'column', borderRight: '1px solid #1e293b' }}>
        <div style={{ padding: '1rem', borderBottom: '1px solid #1e293b', fontWeight: 'bold' }}>
          Workspace Chat
        </div>
        <div style={{ flex: 1, padding: '1rem', overflowY: 'auto' }}>
          {chatMessages.map((msg, idx) => (
            <div key={idx} style={{ marginBottom: '1rem', textAlign: msg.role === 'user' ? 'right' : 'left' }}>
              <div style={{ display: 'inline-block', padding: '0.75rem 1rem', borderRadius: '8px', background: msg.role === 'user' ? '#2563eb' : '#1e293b', maxWidth: '80%' }}>
                <pre style={{ margin: 0, fontFamily: 'inherit', whiteSpace: 'pre-wrap' }}>{msg.content}</pre>
              </div>
            </div>
          ))}
        </div>
        <div style={{ padding: '1rem', borderTop: '1px solid #1e293b', display: 'flex', gap: '0.5rem' }}>
          <input
            type="text"
            value={inputQuery}
            onChange={(e) => setInputQuery(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
            placeholder="Ask questions or enter build instructions..."
            style={{ flex: 1, background: '#1e293b', border: '1px solid #334155', color: '#fff', padding: '0.75rem', borderRadius: '6px' }}
          />
          <button onClick={handleSendMessage} style={{ background: '#2563eb', color: '#fff', border: 'none', padding: '0.75rem 1.25rem', borderRadius: '6px', cursor: 'pointer' }}>
            Send
          </button>
        </div>
      </div>

      {/* RIGHT PANEL: Studio Controls & Actions */}
      <div style={{ padding: '1rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <h3 style={{ fontSize: '0.9rem', color: '#94a3b8', textTransform: 'uppercase' }}>Studio Actions</h3>
        
        {currentAppId ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{ padding: '0.75rem', background: '#1e293b', borderRadius: '6px', fontSize: '0.85rem' }}>
              Active App: <strong>{currentAppId}</strong>
            </div>

            {/* Download Button */}
            <a
              href={`/api/workspace/${currentAppId}/download`}
              download
              style={{ display: 'block', textAlign: 'center', background: '#059669', color: '#fff', textDecoration: 'none', padding: '0.75rem', borderRadius: '6px', fontWeight: 'bold' }}
            >
              ⬇️ Download Workspace (ZIP)
            </a>

            {/* Surge Publish Button */}
            <button
              onClick={handleDeploySurge}
              disabled={isDeploying}
              style={{ background: '#7c3aed', color: '#fff', border: 'none', padding: '0.75rem', borderRadius: '6px', fontWeight: 'bold', cursor: 'pointer' }}
            >
              {isDeploying ? 'Publishing to Surge...' : '🚀 Publish to Surge'}
            </button>

            {surgeUrl && (
              <div style={{ padding: '0.75rem', background: '#064e3b', border: '1px solid #059669', borderRadius: '6px', fontSize: '0.85rem' }}>
                Published Live URL:<br />
                <a href={surgeUrl} target="_blank" rel="noreferrer" style={{ color: '#34d399', wordBreak: 'break-all' }}>
                  {surgeUrl}
                </a>
              </div>
            )}
          </div>
        ) : (
          <p style={{ fontSize: '0.8rem', color: '#64748b' }}>Generate an application workspace in chat to enable download and deployment controls.</p>
        )}
      </div>

    </div>
  );
}
