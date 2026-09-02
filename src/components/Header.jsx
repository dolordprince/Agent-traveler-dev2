import React from 'react';

export function Header({ onOpenApiKeys, onDeploy }) {
  return (
    <header className="app-header">
      <div style={{ display: 'flex', alignItems: 'center', gap: '1.5rem' }}>
        <div className="brand-logo">
          <span style={{ fontSize: '1.25rem' }}>🪐</span>
          <span>TRAVELER.DEV</span>
        </div>
        
        <div className="status-badge">
          <span className="status-dot"></span>
          <span>Online</span>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <select className="btn-secondary" style={{ paddingRight: '1rem' }}>
          <option>My Workspace</option>
        </select>
      </div>

      <div className="header-actions">
        <button className="btn-secondary" onClick={onOpenApiKeys}>
          🔑 API Keys
        </button>
        <button className="btn-primary" onClick={onDeploy}>
          🚀 Test & Deploy
        </button>
      </div>
    </header>
  );
}
