import { WebContainer } from '@webcontainer/api';

const BACKEND_URL = "https://agent-traveler-dev2.onrender.com";

let webcontainerInstance;

window.addEventListener('DOMContentLoaded', async () => {
  const statusEl = document.getElementById('status-container');
  const iframeEl = document.getElementById('preview-iframe');
  const buildBtn = document.getElementById('build-btn');
  const promptInput = document.getElementById('prompt');

  try {
    statusEl.innerText = "⏳ Booting WebContainer...";
    // Boot WebContainer
    webcontainerInstance = await WebContainer.boot();
    statusEl.innerText = "🟢 WebContainer Ready";
    statusEl.style.color = "#4ade80";

    // Listen for server ready inside container
    webcontainerInstance.on('server-ready', (port, url) => {
      iframeEl.src = url;
      document.getElementById('project-status').innerText = `App running at ${url}`;
    });

  } catch (err) {
    console.error("WebContainer Boot Error:", err);
    statusEl.innerText = "⚠️ Boot Failed (Check COOP/COEP headers)";
    statusEl.style.color = "#f87171";
  }

  // Interrogate Backend when Build button is clicked
  buildBtn.addEventListener('click', async () => {
    const promptText = promptInput.value.trim();
    if (!promptText) return alert("Please enter a prompt!");

    buildBtn.disabled = true;
    buildBtn.innerText = "⚡ Communicating with Backend...";

    try {
      // 1. Call Backend to generate project files
      const response = await fetch(`${BACKEND_URL}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: promptText })
      });

      if (!response.ok) throw new Error("Backend generation failed");
      const filesTree = await response.json();

      // 2. Mount files inside StackBlitz WebContainer
      buildBtn.innerText = "📁 Mounting files to WebContainer...";
      await webcontainerInstance.mount(filesTree);

      // 3. Install dependencies
      buildBtn.innerText = "📦 Installing dependencies (npm install)...";
      const installProcess = await webcontainerInstance.spawn('npm', ['install']);
      await installProcess.exit;

      // 4. Start Development Server
      buildBtn.innerText = "🚀 Starting Dev Server (npm run dev)...";
      await webcontainerInstance.spawn('npm', ['run', 'dev']);

      buildBtn.innerText = "✨ App Built & Live!";
    } catch (err) {
      console.error(err);
      alert("Integration Error: " + err.message);
      buildBtn.innerText = "✨ Generate & Build";
    } finally {
      buildBtn.disabled = false;
    }
  });
});
