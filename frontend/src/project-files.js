const TEXT_TYPES = new Set([
  "text",
  "source",
  "code",
  "javascript",
  "typescript",
  "json",
  "html",
  "css",
  "markdown",
  "md"
]);

function normalizePath(path) {
  if (typeof path !== "string") {
    throw new TypeError("Project file path must be a string");
  }

  let normalized = path.trim().replace(/\\/g, "/");

  while (normalized.startsWith("/")) {
    normalized = normalized.slice(1);
  }

  normalized = normalized.replace(/\/{2,}/g, "/");

  if (!normalized || normalized === ".") {
    throw new Error("Project file path cannot be empty");
  }

  const parts = normalized.split("/");

  if (parts.some(function (part) {
    return part === "..";
  })) {
    throw new Error("Project file path cannot contain '..': " + normalized);
  }

  return normalized;
}

function normalizeContent(path, content) {
  const normalizedPath = normalizePath(path);

  if (typeof content === "string") {
    return content;
  }

  if (content === null || content === undefined) {
    return "";
  }

  if (
    typeof content === "object" &&
    typeof content.contents === "string"
  ) {
    return content.contents;
  }

  throw new TypeError(
    "File content must be a string: " + normalizedPath
  );
}

export function normalizeProjectFiles(input) {
  if (input === null || input === undefined) {
    return {};
  }

  let entries;

  if (Array.isArray(input)) {
    entries = input.map(function (item) {
      if (!item || typeof item !== "object") {
        throw new TypeError("Each project file must be an object");
      }

      return [
        item.path || item.name,
        item.content !== undefined ? item.content : item.contents
      ];
    });
  } else if (typeof input === "object") {
    entries = Object.entries(input);
  } else {
    throw new TypeError("Project files must be an object or array");
  }

  const result = {};

  for (const entry of entries) {
    const path = normalizePath(entry[0]);
    result[path] = normalizeContent(path, entry[1]);
  }

  return result;
}

export function projectFilesToStackBlitz(input) {
  const files = normalizeProjectFiles(input);
  const result = {};

  for (const [path, content] of Object.entries(files)) {
    result[path] = {
      file: {
        contents: content
      }
    };
  }

  return result;
}

export function projectFilesFromStackBlitz(input) {
  if (!input || typeof input !== "object") {
    return {};
  }

  const result = {};

  for (const [rawPath, value] of Object.entries(input)) {
    const path = normalizePath(rawPath);

    if (
      value &&
      typeof value === "object" &&
      value.file &&
      typeof value.file.contents === "string"
    ) {
      result[path] = value.file.contents;
      continue;
    }

    result[path] = normalizeContent(path, value);
  }

  return result;
}

export function isTextProjectFile(path) {
  const normalizedPath = normalizePath(path);
  const lower = normalizedPath.toLowerCase();

  if (
    lower.endsWith(".png") ||
    lower.endsWith(".jpg") ||
    lower.endsWith(".jpeg") ||
    lower.endsWith(".gif") ||
    lower.endsWith(".webp") ||
    lower.endsWith(".ico") ||
    lower.endsWith(".woff") ||
    lower.endsWith(".woff2") ||
    lower.endsWith(".ttf") ||
    lower.endsWith(".eot")
  ) {
    return false;
  }

  return true;
}

export function createProjectFile(path, content) {
  const normalizedPath = normalizePath(path);

  return {
    path: normalizedPath,
    content: normalizeContent(normalizedPath, content),
    type: isTextProjectFile(normalizedPath) ? "text" : "binary"
  };
}

export function createProjectFiles(entries) {
  const files = normalizeProjectFiles(entries);

  return Object.entries(files).map(function (entry) {
    return createProjectFile(entry[0], entry[1]);
  });
}

export function getProjectFile(input, path) {
  const files = normalizeProjectFiles(input);
  const normalizedPath = normalizePath(path);

  if (!Object.prototype.hasOwnProperty.call(files, normalizedPath)) {
    return null;
  }

  return files[normalizedPath];
}

export function setProjectFile(input, path, content) {
  const files = normalizeProjectFiles(input);
  const normalizedPath = normalizePath(path);

  files[normalizedPath] = normalizeContent(normalizedPath, content);

  return files;
}

export function deleteProjectFile(input, path) {
  const files = normalizeProjectFiles(input);
  const normalizedPath = normalizePath(path);

  delete files[normalizedPath];

  return files;
}

export function projectFileCount(input) {
  return Object.keys(normalizeProjectFiles(input)).length;
}

export { normalizePath, normalizeContent, TEXT_TYPES };


export const starterProjectFiles = {
  "index.html": "<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>Traveler Dev Workspace</title>\n</head>\n<body>\n  <div id=\"root\"></div>\n  <script type=\"module\" src=\"/src/main.js\"></script>\n</body>\n</html>\n",

  "package.json": "{\n  \"name\": \"traveler-dev-project\",\n  \"private\": true,\n  \"version\": \"1.0.0\",\n  \"type\": \"module\",\n  \"scripts\": {\n    \"dev\": \"vite\",\n    \"build\": \"vite build\",\n    \"preview\": \"vite preview\"\n  }\n}\n",

  "src/main.js": "const root = document.getElementById('root');\nif (root) {\n  root.innerHTML = '<main><h1>Traveler Dev</h1><p>Workspace project ready.</p></main>';\n}\n"
};
