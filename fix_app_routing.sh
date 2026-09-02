#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Updating App.jsx to render NotebookWorkspace directly ==="
cat << 'APPEOF' > src/App.jsx
import React from 'react';
import NotebookWorkspace from './components/NotebookWorkspace';

export default function App() {
  return <NotebookWorkspace />;
}
APPEOF

echo "=== [2/3] Registering Service Worker in main.jsx ==="
cat << 'MAINEOF' > src/main.jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').then(
      (reg) => console.log('SW registered:', reg.scope),
      (err) => console.log('SW registration failed:', err)
    );
  });
}
MAINEOF

echo "=== [3/3] Committing & Pushing Fix to GitHub ==="
git add src/App.jsx src/main.jsx
git commit -m "fix: mount NotebookWorkspace in App.jsx and register SW" || echo "No changes to commit"
git push origin main

echo "Pushed to GitHub main! Vercel build will trigger immediately."
