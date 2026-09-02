#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Updating CSS Theme Variables & Styles ==="
cat << 'CSSEOF' > src/index.css
:root {
  --bg-primary: #0b0f19;
  --bg-secondary: #111827;
  --bg-card: rgba(17, 24, 39, 0.7);
  --border-color: rgba(255, 255, 255, 0.08);
  --accent-purple: #8b5cf6;
  --accent-blue: #3b82f6;
  --text-primary: #f9fafb;
  --text-secondary: #9ca3af;
}

body {
  background-color: var(--bg-primary);
  color: var(--text-primary);
  font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  margin: 0;
  padding: 0;
}

/* App Header */
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.25rem;
  background-color: rgba(15, 23, 42, 0.85);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--border-color);
}

.brand-logo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 700;
  font-size: 1.125rem;
  background: linear-gradient(135deg, #a855f7, #6366f1);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.25rem 0.625rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  background: rgba(34, 197, 94, 0.1);
  color: #4ade80;
  border: 1px solid rgba(34, 197, 94, 0.2);
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background-color: #22c55e;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.btn-primary {
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #ffffff;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn-primary:hover {
  opacity: 0.9;
}

.btn-secondary {
  background: rgba(255, 255, 255, 0.05);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
  padding: 0.5rem 0.875rem;
  border-radius: 0.5rem;
  cursor: pointer;
}
CSSEOF

echo "=== 2. Creating Header Component ==="
mkdir -p src/components
cat << 'HEADEREOF' > src/components/Header.jsx
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
HEADEREOF

echo "=== 3. Committing and Pushing Changes ==="
git add src/index.css src/components/Header.jsx
git commit -m "style: apply dark workspace theme and restructure header UI" || true
git push origin main

echo "=== Done! Spaces will trigger automatic build ==="
