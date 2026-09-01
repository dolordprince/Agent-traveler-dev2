import {
  WebContainer,
  type FileSystemTree,
  type WebContainerProcess
} from "@webcontainer/api";

import "./style.css";

const API =
  (import.meta.env.VITE_AGENT_API_URL ||
    "https://agent-traveler-dev2.onrender.com").replace(/\/$/, "");

type ProjectFile = {
  path: string;
  content: string;
};

let container: WebContainer | null = null;
let devProcess: WebContainerProcess | null = null;
let bootPromise: Promise<WebContainer> | null = null;
let currentFiles: ProjectFile[] = [];

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Traveler Dev application root not found");
}

app.innerHTML = `
  <div class="shell">
    <header class="topbar">
      <div class="brand">
        <div class="logo">T</div>
        <div>
          <strong>TRAVELER DEV</strong>
          <span>AI development workspace</span>
        </div>
      </div>

      <div class="runtime">
        <span id="runtimeDot" class="dot offline"></span>
        <span id="runtimeStatus">WebContainer offline</span>
      </div>
    </header>

    <section class="commandbar">
      <textarea
        id="prompt"
        spellcheck="false"
        placeholder="Describe the real application you want Traveler Dev to build..."
      ></textarea>

      <button id="buildButton" class="primary">
        Build
      </button>
    </section>

    <main class="workspace">
      <aside class="sidebar">
        <div class="panelTitle">PROJECT</div>
        <pre id="fileTree">No project loaded.</pre>
      </aside>

      <section class="center">
        <div class="previewHeader">
          <div>
            <strong>HTTP Preview</strong>
            <span id="previewUrl">Waiting for application...</span>
          </div>

          <div class="actions">
            <button id="openPreview">Open</button>
            <button id="reloadPreview">Reload</button>
            <button id="stopPreview">Stop</button>
          </div>
        </div>

        <div class="preview">
          <iframe
            id="previewFrame"
            title="Traveler Dev application preview"
            sandbox="allow-forms allow-modals allow-popups allow-presentation allow-same-origin allow-scripts"
          ></iframe>

          <div id="previewEmpty" class="empty">
            <div class="emptyIcon">▶</div>
            <strong>Application preview</strong>
            <span>Build a project to start the real WebContainer.</span>
          </div>
        </div>

        <div class="terminal">
          <div class="terminalHeader">
            <strong>Terminal</strong>
            <span id="terminalStatus">Ready</span>
          </div>
          <pre id="terminalOutput"></pre>
        </div>
      </section>
    </main>
  </div>
`;

const promptEl =
  document.querySelector<HTMLTextAreaElement>("#prompt")!;

const buildButton =
  document.querySelector<HTMLButtonElement>("#buildButton")!;

const fileTree =
  document.querySelector<HTMLPreElement>("#fileTree")!;

const previewFrame =
  document.querySelector<HTMLIFrameElement>("#previewFrame")!;

const previewUrl =
  document.querySelector<HTMLSpanElement>("#previewUrl")!;

const previewEmpty =
  document.querySelector<HTMLDivElement>("#previewEmpty")!;

const terminalOutput =
  document.querySelector<HTMLPreElement>("#terminalOutput")!;

const terminalStatus =
  document.querySelector<HTMLSpanElement>("#terminalStatus")!;

const runtimeStatus =
  document.querySelector<HTMLSpanElement>("#runtimeStatus")!;

const runtimeDot =
  document.querySelector<HTMLSpanElement>("#runtimeDot")!;

function log(message: string) {
  terminalOutput.textContent += `${message}\n`;
  terminalOutput.scrollTop = terminalOutput.scrollHeight;
}

function setRuntime(online: boolean, message: string) {
  runtimeStatus.textContent = message;
  runtimeDot.className = online
    ? "dot online"
    : "dot offline";
}

function renderFiles(files: ProjectFile[]) {
  fileTree.textContent = files
    .map((file) => file.path)
    .sort()
    .join("\n");
}

function filesToTree(files: ProjectFile[]): FileSystemTree {
  const root: FileSystemTree = {};

  for (const item of files) {
    const parts = item.path
      .replaceAll("\\", "/")
      .replace(/^\/+/, "")
      .split("/")
      .filter(Boolean);

    if (!parts.length || parts.includes("..")) {
      throw new Error(`Invalid project path: ${item.path}`);
    }

    let cursor: Record<string, any> = root as Record<string, any>;

    for (let i = 0; i < parts.length - 1; i++) {
      const part = parts[i];

      if (!cursor[part]) {
        cursor[part] = {
          directory: {}
        };
      }

      cursor = cursor[part].directory;
    }

    cursor[parts[parts.length - 1]] = {
      file: {
        contents: item.content
      }
    };
  }

  return root;
}

async function getContainer(): Promise<WebContainer> {
  if (container) {
    return container;
  }

  if (bootPromise) {
    return bootPromise;
  }

  bootPromise = WebContainer.boot();

  try {
    container = await bootPromise;

    container.on("error", (error) => {
      log(`[WebContainer] ${error.message}`);
    });

    container.on("port", (port, type) => {
      log(`[port] ${port} ${type}`);
    });

    return container;
  } finally {
    bootPromise = null;
  }
}

async function mountProject(files: ProjectFile[]) {
  const wc = await getContainer();

  if (devProcess) {
    try {
      devProcess.kill();
    } catch {
      // Process may already be stopped.
    }

    devProcess = null;
  }

  await wc.mount(filesToTree(files));

  log(`[mount] ${files.length} files mounted`);

  const packageCheck = await wc.fs.readFile(
    "package.json",
    "utf-8"
  );

  if (!packageCheck.trim()) {
    throw new Error("Generated project has an empty package.json");
  }

  renderFiles(files);
}

async function streamProcess(
  process: WebContainerProcess,
  prefix: string
) {
  await process.output.pipeTo(
    new WritableStream({
      write(data) {
        log(`${prefix} ${data}`);
      }
    })
  );
}

async function installDependencies() {
  if (!container) {
    throw new Error("WebContainer is not booted");
  }

  terminalStatus.textContent = "Installing dependencies...";
  log("$ npm install");

  const install = await container.spawn("npm", [
    "install",
    "--no-audit",
    "--no-fund"
  ]);

  await Promise.all([
    install.exit,
    streamProcess(install, "[npm]")
  ]);

  const exitCode = await install.exit;

  if (exitCode !== 0) {
    throw new Error(
      `npm install failed with exit code ${exitCode}`
    );
  }

  log("[npm] dependencies installed");
}

async function startPreview() {
  if (!container) {
    throw new Error("WebContainer is not booted");
  }

  terminalStatus.textContent = "Starting preview...";

  const ready = new Promise<string>((resolve, reject) => {
    let settled = false;

    const unsubscribe = container!.on(
      "server-ready",
      (port, url) => {
        if (settled) return;

        settled = true;
        unsubscribe();

        log(`[preview] server ready on port ${port}`);
        log(`[preview] ${url}`);

        resolve(url);
      }
    );

    container!.on("error", (error) => {
      if (!settled) {
        settled = true;
        unsubscribe();
        reject(error);
      }
    });
  });

  devProcess = await container.spawn(
    "npm",
    ["run", "dev", "--", "--host", "0.0.0.0"]
  );

  void streamProcess(devProcess, "[dev]");

  const url = await ready;

  previewFrame.src = url;
  previewUrl.textContent = url;
  previewEmpty.style.display = "none";
  terminalStatus.textContent = "Preview ready";

  setRuntime(true, "WebContainer running");
}

async function requestProject(prompt: string): Promise<ProjectFile[]> {
  const response = await fetch(
    `${API}/api/agent/run`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        messages: [
          {
            role: "user",
            content: `
Build the requested production web application.

Return ONLY valid JSON.
Do not use markdown fences.
Do not explain anything.

Required JSON shape:
{
  "files": [
    {
      "path": "package.json",
      "content": "..."
    }
  ]
}

The project MUST:
- run with npm install
- run with npm run dev
- use a real Vite development server
- include package.json
- include index.html
- include all required source files
- contain no fake APIs
- contain no placeholder implementation
- contain no markdown outside the JSON

User request:
\${prompt}
            `.trim()
          }
        ]
      })
    }
  );

  if (!response.ok) {
    throw new Error(
      `Agent API returned HTTP ${response.status}`
    );
  }

  const data = await response.json();

  if (!data.success) {
    throw new Error(
      data.error || "Traveler Dev agent failed"
    );
  }

  const raw = String(data.content || "").trim();

  let parsed: unknown;

  try {
    parsed = JSON.parse(raw);
  } catch {
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");

    if (start === -1 || end === -1 || end <= start) {
      throw new Error(
        "Agent returned invalid project JSON"
      );
    }

    parsed = JSON.parse(
      raw.slice(start, end + 1)
    );
  }

  if (
    !parsed ||
    typeof parsed !== "object" ||
    !Array.isArray(
      (parsed as { files?: unknown }).files
    )
  ) {
    throw new Error(
      "Agent response does not contain a files array"
    );
  }

  const files = (
    parsed as {
      files: Array<{
        path?: unknown;
        content?: unknown;
      }>;
    }
  ).files;

  const result: ProjectFile[] = [];

  for (const item of files) {
    if (
      typeof item.path !== "string" ||
      typeof item.content !== "string"
    ) {
      throw new Error(
        "Invalid project file returned by agent"
      );
    }

    result.push({
      path: item.path,
      content: item.content
    });
  }

  if (!result.some((file) => file.path === "package.json")) {
    throw new Error(
      "Generated project is missing package.json"
    );
  }

  if (!result.some((file) => file.path === "index.html")) {
    throw new Error(
      "Generated project is missing index.html"
    );
  }

  return result;
}

async function buildProject() {
  const prompt = promptEl.value.trim();

  if (!prompt) {
    promptEl.focus();
    return;
  }

  buildButton.disabled = true;
  terminalOutput.textContent = "";
  terminalStatus.textContent = "Generating project...";
  setRuntime(false, "Generating project...");

  try {
    log(`[agent] ${API}`);
    log("[agent] Generating production project...");

    currentFiles = await requestProject(prompt);

    log(
      `[agent] Received ${currentFiles.length} project files`
    );

    await mountProject(currentFiles);
    await installDependencies();
    await startPreview();

    log("[traveler-dev] PROJECT READY");
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : String(error);

    log(`[ERROR] ${message}`);
    terminalStatus.textContent = "Build failed";
    setRuntime(false, "WebContainer error");
  } finally {
    buildButton.disabled = false;
  }
}

buildButton.addEventListener(
  "click",
  () => void buildProject()
);

promptEl.addEventListener("keydown", (event) => {
  if (
    event.key === "Enter" &&
    (event.ctrlKey || event.metaKey)
  ) {
    event.preventDefault();
    void buildProject();
  }
  });

document
  .querySelector<HTMLButtonElement>("#openPreview")!
  .addEventListener("click", () => {
    if (previewFrame.src) {
      window.open(
        previewFrame.src,
        "_blank",
        "noopener,noreferrer"
      );
    }
  });

document
  .querySelector<HTMLButtonElement>("#reloadPreview")!
  .addEventListener("click", () => {
    if (previewFrame.src) {
      previewFrame.src = previewFrame.src;
    }
  });

document
  .querySelector<HTMLButtonElement>("#stopPreview")!
  .addEventListener("click", () => {
    if (devProcess) {
      try {
        devProcess.kill();
      } catch {
        // Ignore an already terminated process.
      }

      devProcess = null;
    }

    previewFrame.removeAttribute("src");
    previewUrl.textContent = "Preview stopped";
    previewEmpty.style.display = "flex";
    terminalStatus.textContent = "Stopped";
    setRuntime(false, "WebContainer stopped");

    log("[preview] stopped");
  });

setRuntime(false, "WebContainer offline");
