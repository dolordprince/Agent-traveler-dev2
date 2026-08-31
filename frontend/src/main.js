import './style.css';
import {
  bootWebContainer,
  writeProjectFiles,
  runWebContainerCommand,
  getWebContainerState,
} from './stackblitz.js';
import { starterProjectFiles } from './project-files.js';

const state = {
  activeFile: 'src/main.js',
  files: {
    'src/main.js': starterProjectFiles['src/main.js'],
    'index.html': starterProjectFiles['index.html'],
    'package.json': starterProjectFiles['package.json'],
  },
  terminal: [],
};

const root = document.querySelector('#root') || document.querySelector('#app');

root.innerHTML = `
<div class="app-shell">

  <header class="topbar">
    <button class="icon-button mobile-only" id="menuButton" aria-label="Open menu">☰</button>

    <div class="brand">
      <div class="brand-mark">&lt;/&gt;</div>
      <div>
        <strong>TRAVELER DEV</strong>
        <span>AI DEVELOPMENT WORKSPACE</span>
      </div>
    </div>

    <div class="top-actions">
      <span id="containerStatus" class="status">
        <i></i> WebContainer offline
      </span>
      <button id="bootButton" class="button primary">Start Workspace</button>
    </div>
  </header>

  <main class="workspace">

    <aside class="sidebar" id="sidebar">
      <div class="sidebar-head">
        <span>EXPLORER</span>
        <button class="icon-button" id="newFileButton" title="New file">+</button>
      </div>

      <div class="project-name">
        <span>⌄</span>
        <strong>TRAVELER PROJECT</strong>
      </div>

      <div class="tree" id="fileTree"></div>

      <div class="sidebar-bottom">
        <button class="side-action" id="terminalButton">〉_ Terminal</button>
        <button class="side-action" id="previewButton">◫ Preview</button>
      </div>
    </aside>

    <section class="editor-area">

      <div class="tabs" id="tabs">
        <div class="tab active">
          <span class="file-icon">JS</span>
          <span id="activeTabName">main.js</span>
          <button id="closeTab">×</button>
        </div>
      </div>

      <div class="editor-toolbar">
        <span id="breadcrumb">src / main.js</span>

        <div>
          <button class="toolbar-button" id="runButton">▶ Run</button>
          <button class="toolbar-button" id="buildButton">✓ Build</button>
        </div>
      </div>

      <div class="editor" id="editor">
        <div class="line-numbers" id="lineNumbers"></div>
        <textarea id="codeEditor" spellcheck="false"></textarea>
      </div>

      <section class="terminal-panel" id="terminalPanel">
        <div class="panel-header">
          <span>TERMINAL</span>
          <button id="clearTerminal">Clear</button>
        </div>
        <pre id="terminalOutput">Traveler Dev terminal ready.</pre>
      </section>

      <section class="preview-panel" id="previewPanel">
        <div class="panel-header">
          <span>PREVIEW</span>
          <button id="closePreview">×</button>
        </div>
        <div class="preview-empty">
          <div class="preview-icon">◫</div>
          <strong>WebContainer preview</strong>
          <p>Start the workspace and run the project to receive the live preview URL.</p>
          <button class="button primary" id="previewStart">Start Preview</button>
        </div>
        <iframe id="previewFrame" title="Application preview"></iframe>
      </section>

    </section>

    <aside class="ai-panel">
      <div class="ai-header">
        <div>
          <strong>TRAVELER AI</strong>
          <span>AGENT</span>
        </div>
        <span class="ai-dot"></span>
      </div>

      <div class="chat" id="chat">
        <div class="assistant-message">
          <strong>Traveler Dev</strong>
          <p>
            Workspace connected. I can inspect the project, edit files,
            run commands and prepare the application for deployment.
          </p>
        </div>
      </div>

      <form class="prompt-box" id="promptForm">
        <textarea
          id="prompt"
          rows="3"
          placeholder="Ask Traveler Dev to build or modify your application..."
        ></textarea>

        <div class="prompt-actions">
          <span>Enter to send · Shift+Enter for new line</span>
          <button type="submit" class="send-button">↑</button>
        </div>
      </form>
    </aside>

  </main>

  <footer class="statusbar">
    <span id="connectionStatus">LOCAL WORKSPACE</span>
    <span>UTF-8</span>
    <span>JavaScript</span>
    <span id="workspaceState">READY</span>
  </footer>

</div>
`;

const editor = document.querySelector('#codeEditor');
const lineNumbers = document.querySelector('#lineNumbers');
const fileTree = document.querySelector('#fileTree');
const terminalOutput = document.querySelector('#terminalOutput');
const containerStatus = document.querySelector('#containerStatus');
const workspaceState = document.querySelector('#workspaceState');
const terminalPanel = document.querySelector('#terminalPanel');
const previewPanel = document.querySelector('#previewPanel');
const previewFrame = document.querySelector('#previewFrame');

function basename(path) {
  return path.split('/').pop();
}

function renderTree() {
  fileTree.innerHTML = '';

  Object.keys(state.files).forEach(path => {
    const row = document.createElement('button');
    row.className = `tree-row ${state.activeFile === path ? 'selected' : ''}`;

    const icon = path.endsWith('.js')
      ? 'JS'
      : path.endsWith('.html')
        ? 'HTML'
        : path.endsWith('.json')
          ? '{}'
          : '•';

    row.innerHTML = `
      <span class="file-icon">${icon}</span>
      <span>${path}</span>
    `;

    row.addEventListener('click', () => openFile(path));
    fileTree.appendChild(row);
  });
}

function updateEditor() {
  editor.value = state.files[state.activeFile] ?? '';
  document.querySelector('#activeTabName').textContent = basename(state.activeFile);
  document.querySelector('#breadcrumb').textContent =
    state.activeFile.replaceAll('/', ' / ');

  updateLineNumbers();
  renderTree();
}

function updateLineNumbers() {
  const count = Math.max(1, editor.value.split('\n').length);
  lineNumbers.textContent = Array.from(
    { length: count },
    (_, index) => index + 1,
  ).join('\n');
}

function openFile(path) {
  if (!(path in state.files)) return;

  state.files[state.activeFile] = editor.value;
  state.activeFile = path;
  updateEditor();
}

function terminal(message) {
  state.terminal.push(message);
  terminalOutput.textContent = state.terminal.join('\n');
  terminalOutput.scrollTop = terminalOutput.scrollHeight;
}

function setStatus(status, label) {
  containerStatus.className = `status ${status}`;
  containerStatus.innerHTML = `<i></i> ${label}`;
  workspaceState.textContent = status.toUpperCase();
}

async function boot() {
  try {
    setStatus('booting', 'Booting WebContainer...');

    await bootWebContainer(state.files);

    setStatus('ready', 'WebContainer ready');
    terminal('$ WebContainer booted');
    terminal('✓ Project files mounted');
  } catch (error) {
    setStatus('error', 'WebContainer unavailable');
    terminal(`ERROR: ${error.message}`);
  }
}

async function syncFiles() {
  state.files[state.activeFile] = editor.value;
  await writeProjectFiles(state.files);
}

async function run(command, args = []) {
  try {
    await syncFiles();

    terminal(`$ ${command} ${args.join(' ')}`);

    const result = await runWebContainerCommand(command, args);

    if (result.output) {
      terminal(result.output);
    }

    terminal(`Process exited with code ${result.exitCode}`);

    return result;
  } catch (error) {
    terminal(`ERROR: ${error.message}`);
    return null;
  }
}

document.querySelector('#bootButton').addEventListener('click', boot);

document.querySelector('#runButton').addEventListener('click', async () => {
  await run('npm', ['run', 'dev', '--', '--host', '0.0.0.0']);
});

document.querySelector('#buildButton').addEventListener('click', async () => {
  await run('npm', ['run', 'build']);
});

document.querySelector('#terminalButton').addEventListener('click', () => {
  terminalPanel.classList.toggle('visible');
  previewPanel.classList.remove('visible');
});

document.querySelector('#previewButton').addEventListener('click', () => {
  previewPanel.classList.toggle('visible');
  terminalPanel.classList.remove('visible');
});

document.querySelector('#closePreview').addEventListener('click', () => {
  previewPanel.classList.remove('visible');
});

document.querySelector('#previewStart').addEventListener('click', async () => {
  await run('npm', ['run', 'dev', '--', '--host', '0.0.0.0']);
});

document.querySelector('#clearTerminal').addEventListener('click', () => {
  state.terminal = [];
  terminalOutput.textContent = '';
});

document.querySelector('#codeEditor').addEventListener('input', () => {
  state.files[state.activeFile] = editor.value;
  updateLineNumbers();
});

editor.addEventListener('scroll', () => {
  lineNumbers.scrollTop = editor.scrollTop;
});

document.querySelector('#promptForm').addEventListener('submit', event => {
  event.preventDefault();

  const input = document.querySelector('#prompt');
  const message = input.value.trim();

  if (!message) return;

  const chat = document.querySelector('#chat');

  const user = document.createElement('div');
  user.className = 'user-message';
  user.textContent = message;
  chat.appendChild(user);

  input.value = '';

  const assistant = document.createElement('div');
  assistant.className = 'assistant-message';
  assistant.innerHTML = `
    <strong>Traveler Dev</strong>
    <p>Request received. The AI gateway is ready to process this workspace operation.</p>
  `;
  chat.appendChild(assistant);

  chat.scrollTop = chat.scrollHeight;
});

document.querySelector('#menuButton').addEventListener('click', () => {
  document.querySelector('#sidebar').classList.toggle('mobile-open');
});

window.addEventListener('traveler:webcontainer-status', event => {
  const detail = event.detail;

  if (detail.status === 'booting') {
    setStatus('booting', 'Booting WebContainer...');
  } else if (detail.status === 'ready') {
    setStatus('ready', 'WebContainer ready');
  } else if (detail.status === 'error') {
    setStatus('error', 'WebContainer error');
  }
});

window.addEventListener('traveler:webcontainer-server-ready', event => {
  const url = event.detail.url;

  terminal(`✓ Preview server ready: ${url}`);

  previewPanel.classList.add('visible');
  previewFrame.src = url;
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  });
}

renderTree();
updateEditor();
