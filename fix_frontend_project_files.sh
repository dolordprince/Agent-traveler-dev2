#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$ROOT/frontend"
SRC="$FRONTEND/src"

echo "============================================================"
echo "TRAVELER DEV — PROJECT FILES FINAL FIX + BUILD"
echo "============================================================"

test -d "$FRONTEND" || {
    echo "FAIL: $FRONTEND does not exist"
    exit 1
}

mkdir -p "$SRC"

cat > "$SRC/project-files.js" <<'JS'
const DEFAULT_FILES = {
  "package.json": `{
  "name": "traveler-dev-project",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  }
}`,

  "index.html": `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <title>Traveler Dev Project</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>`,

  "src/main.js": `import "./style.css";

const root = document.getElementById("root");

if (root) {
  root.innerHTML = \`
    <main class="traveler-dev-app">
      <h1>Traveler Dev</h1>
      <p>Project workspace ready.</p>
    </main>
  \`;
}
`,

  "src/style.css": `:root {
  font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color-scheme: dark;
  background: #0b0d12;
  color: #f5f7fb;
}

* {
  box-sizing: border-box;
}

html,
body,
#root {
  margin: 0;
  width: 100%;
  min-width: 320px;
  min-height: 100%;
}

body {
  min-height: 100vh;
  background: #0b0d12;
}

.traveler-dev-app {
  min-height: 100vh;
  padding: 40px;
}
`
};

function normalizePath(value) {
  if (typeof value !== "string") {
    throw new TypeError("File path must be a string");
  }

  const path = value
    .replaceAll("\\\\", "/")
    .replace(/^\/+/, "")
    .replace(/\/+/g, "/");

  if (
    !path ||
    path === "." ||
    path === ".." ||
    path.startsWith("../") ||
    path.includes("/../") ||
    path.includes("/./")
  ) {
    throw new Error("Invalid project file path");
  }

  return path;
}

function normalizeFiles(files) {
  if (
    files === null ||
    typeof files !== "object" ||
    Array.isArray(files)
  ) {
    throw new TypeError("Project files must be an object");
  }

  const result = {};

  for (const [filePath, content] of Object.entries(files)) {
    const normalizedPath = normalizePath(filePath);

    if (typeof content !== "string") {
      throw new TypeError(
        \`File content must be a string: \${normalizedPath}\`
      );
    }

    result[normalizedPath] = content;
  }

  return result;
}

export function createProjectFiles(files = {}) {
  return {
    ...DEFAULT_FILES,
    ...normalizeFiles(files)
  };
}

export function getProjectFile(files, filePath) {
  const normalized = normalizePath(filePath);
  const normalizedFiles = normalizeFiles(files);

  return Object.prototype.hasOwnProperty.call(
    normalizedFiles,
    normalized
  )
    ? normalizedFiles[normalized]
    : null;
}

export function setProjectFile(files, filePath, content) {
  if (typeof content !== "string") {
    throw new TypeError("File content must be a string");
  }

  return {
    ...normalizeFiles(files),
    [normalizePath(filePath)]: content
  };
}

export function deleteProjectFile(files, filePath) {
  const result = normalizeFiles(files);
  delete result[normalizePath(filePath)];
  return result;
}

export function listProjectFiles(files) {
  return Object.keys(normalizeFiles(files)).sort((a, b) =>
    a.localeCompare(b)
  );
}

export function filesToStackBlitzPayload(files) {
  const normalizedFiles = normalizeFiles(files);
  const payload = {};

  for (const [path, content] of Object.entries(normalizedFiles)) {
    payload[path] = {
      file: {
        contents: content
      }
    };
  }

  return payload;
}

export function stackBlitzPayloadToFiles(payload) {
  if (
    payload === null ||
    typeof payload !== "object" ||
    Array.isArray(payload)
  ) {
    throw new TypeError("Invalid StackBlitz payload");
  }

  const result = {};

  for (const [path, value] of Object.entries(payload)) {
    const contents = value?.file?.contents;

    if (typeof contents === "string") {
      result[normalizePath(path)] = contents;
    }
  }

  return result;
}

export function serializeProjectFiles(files) {
  return JSON.stringify(normalizeFiles(files));
}

export function parseProjectFiles(serialized) {
  if (typeof serialized !== "string") {
    throw new TypeError("Serialized project files must be a string");
  }

  return normalizeFiles(JSON.parse(serialized));
}

export const defaultProjectFiles = Object.freeze(
  createProjectFiles()
);
JS

echo "PASS  project-files.js written"

echo
echo "=== JAVASCRIPT SYNTAX ==="

node --check "$SRC/project-files.js"
node --check "$SRC/main.js"

echo "PASS  project-files.js"
echo "PASS  main.js"

echo
echo "=== MODULE IMPORT TEST ==="

node --input-type=module <<'JS'
import {
  createProjectFiles,
  filesToStackBlitzPayload,
  stackBlitzPayloadToFiles,
  listProjectFiles
} from "./frontend/src/project-files.js";

const files = createProjectFiles({
  "src/test.js": "export const test = true;"
});

const payload = filesToStackBlitzPayload(files);
const restored = stackBlitzPayloadToFiles(payload);
const names = listProjectFiles(restored);

if (!names.includes("src/test.js")) {
  throw new Error("StackBlitz file conversion test failed");
}

if (restored["src/test.js"] !== "export const test = true;") {
  throw new Error("Project file round-trip failed");
}

console.log("PASS  project file round-trip");
console.log("PASS  StackBlitz payload conversion");
JS

echo
echo "=== FRONTEND STRUCTURE ==="

required=(
  "$FRONTEND/index.html"
  "$FRONTEND/package.json"
  "$FRONTEND/vite.config.js"
  "$SRC/main.js"
  "$SRC/style.css"
  "$SRC/stackblitz.js"
  "$SRC/project-files.js"
  "$FRONTEND/public/manifest.webmanifest"
  "$FRONTEND/public/sw.js"
  "$FRONTEND/public/icon.svg"
)

for file in "${required[@]}"; do
  if [ ! -f "$file" ]; then
    echo "FAIL  ${file#$FRONTEND/}"
    exit 1
  fi

  echo "PASS  ${file#$FRONTEND/}"
done

echo
echo "=== FRONTEND INSTALL / BUILD ==="

cd "$FRONTEND"

if [ ! -d node_modules ] || [ ! -x node_modules/.bin/vite ]; then
  echo "Installing frontend dependencies..."
  npm install
else
  echo "PASS  local dependencies"
fi

echo
echo "=== NPM BUILD ==="

npm run build

test -f dist/index.html || {
  echo "FAIL: dist/index.html missing"
  exit 1
}

echo
echo "============================================================"
echo "TRAVELER DEV — FRONTEND BUILD PASS"
echo "============================================================"
echo "Frontend: $FRONTEND"
echo "Build:    $FRONTEND/dist"
echo "PWA:      $FRONTEND/public/manifest.webmanifest"
echo "SW:       $FRONTEND/public/sw.js"
echo "Bridge:   $SRC/stackblitz.js"
echo "Files:    $SRC/project-files.js"
echo "============================================================"
