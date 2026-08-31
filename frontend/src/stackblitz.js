import { projectFilesToStackBlitz } from "./project-files.js";

const ENV =
  typeof import.meta !== "undefined" &&
  import.meta.env
    ? import.meta.env
    : {};

const API_URL =
  ENV.VITE_STACKBLITZ_API_URL ||
  ENV.VITE_WORKSPACE_API_URL ||
  "";

let webContainer = null;
let bootPromise = null;

const state = {
  status: "idle",
  instanceId: null,
  error: null,
  bootedAt: null
};

function setState(values) {
  Object.assign(state, values);

  if (typeof window !== "undefined") {
    window.dispatchEvent(
      new CustomEvent("traveler-dev:webcontainer-state", {
        detail: { ...state }
      })
    );
  }

  return { ...state };
}

export function getWebContainerState() {
  return { ...state };
}

function getWebContainerPackage() {
  return window?.WebContainer || null;
}

async function loadWebContainer() {
  if (webContainer) {
    return webContainer;
  }

  if (typeof window === "undefined") {
    throw new Error("WebContainer is only available in the browser");
  }

  if (window.WebContainer) {
    webContainer = window.WebContainer;
    return webContainer;
  }

  try {
    const module = await import("@webcontainer/api");
    webContainer = module.WebContainer;
    return webContainer;
  } catch (error) {
    throw new Error(
      "WebContainer API is not installed. Install @webcontainer/api in the frontend."
    );
  }
}

export async function bootWebContainer(projectFiles = {}) {
  if (webContainer) {
    return webContainer;
  }

  if (bootPromise) {
    return bootPromise;
  }

  bootPromise = (async function () {
    setState({
      status: "booting",
      error: null
    });

    try {
      const WebContainer = await loadWebContainer();

      if (!WebContainer || typeof WebContainer.boot !== "function") {
        throw new Error("Invalid WebContainer API");
      }

      webContainer = await WebContainer.boot();

      setState({
        status: "ready",
        error: null,
        bootedAt: new Date().toISOString()
      });

      if (Object.keys(projectFiles).length > 0) {
        await writeProjectFiles(projectFiles);
      }

      return webContainer;
    } catch (error) {
      webContainer = null;

      setState({
        status: "error",
        error: error instanceof Error ? error.message : String(error)
      });

      throw error;
    } finally {
      bootPromise = null;
    }
  })();

  return bootPromise;
}

export async function writeProjectFiles(projectFiles) {
  const container = await bootWebContainer();

  const files = projectFilesToStackBlitz(projectFiles);

  if (!container || typeof container.mount !== "function") {
    throw new Error("WebContainer mount API is unavailable");
  }

  await container.mount(files);

  return {
    status: "ok",
    count: Object.keys(projectFiles).length,
    files: Object.keys(projectFiles)
  };
}

export async function runWebContainerCommand(
  command,
  args = [],
  options = {}
) {
  const container = await bootWebContainer();

  if (!command || typeof command !== "string") {
    throw new TypeError("command must be a non-empty string");
  }

  if (!Array.isArray(args)) {
    throw new TypeError("args must be an array");
  }

  if (!container || typeof container.spawn !== "function") {
    throw new Error("WebContainer spawn API is unavailable");
  }

  const process = await container.spawn(command, args, options);

  return process;
}

export async function runProjectCommand(command, args = [], options = {}) {
  return runWebContainerCommand(command, args, options);
}

export async function installProjectDependencies() {
  return runProjectCommand("npm", ["install", "--no-audit", "--no-fund"]);
}

export async function buildProject() {
  return runProjectCommand("npm", ["run", "build"]);
}

export async function startProject() {
  return runProjectCommand("npm", ["run", "dev", "--", "--host", "0.0.0.0"]);
}

export async function openProjectPreview(port = 5173) {
  const container = await bootWebContainer();

  if (!container) {
    throw new Error("WebContainer is not booted");
  }

  if (typeof container.on !== "function") {
    throw new Error("WebContainer event API is unavailable");
  }

  return new Promise(function (resolve, reject) {
    let settled = false;

    const cleanup = function () {
      if (typeof container.off === "function") {
        container.off("server-ready", handleReady);
      }
    };

    const handleReady = function (readyPort, url) {
      if (Number(readyPort) !== Number(port)) {
        return;
      }

      settled = true;
      cleanup();

      resolve({
        status: "ready",
        port: readyPort,
        url
      });
    };

    container.on("server-ready", handleReady);

    setTimeout(function () {
      if (settled) {
        return;
      }

      settled = true;
      cleanup();

      reject(
        new Error(
          "Timed out waiting for WebContainer preview on port " + port
        )
      );
    }, 30000);
  });
}

export async function shutdownWebContainer() {
  if (!webContainer) {
    setState({
      status: "idle",
      instanceId: null,
      error: null
    });

    return {
      status: "idle"
    };
  }

  if (typeof webContainer.teardown === "function") {
    await webContainer.teardown();
  }

  webContainer = null;

  setState({
    status: "idle",
    instanceId: null,
    error: null
  });

  return {
    status: "idle"
  };
}

export function getStackBlitzApiUrl() {
  return API_URL;
}

export function isWebContainerAvailable() {
  return Boolean(
    typeof window !== "undefined" &&
    (
      window.WebContainer ||
      API_URL
    )
  );
}

export function webcontainerStatus() {
  return {
    ...getWebContainerState(),
    apiUrl: API_URL,
    available: isWebContainerAvailable()
  };
}
