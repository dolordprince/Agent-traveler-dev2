#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Agent-traveler-dev2"
FILE="$ROOT/frontend/src/project-files.js"

cd "$ROOT"

python - "$FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

if "export const starterProjectFiles" not in text:
    text += r'''

export const starterProjectFiles = {
  "index.html": "<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>Traveler Dev Workspace</title>\n</head>\n<body>\n  <div id=\"root\"></div>\n  <script type=\"module\" src=\"/src/main.js\"></script>\n</body>\n</html>\n",

  "package.json": "{\n  \"name\": \"traveler-dev-project\",\n  \"private\": true,\n  \"version\": \"1.0.0\",\n  \"type\": \"module\",\n  \"scripts\": {\n    \"dev\": \"vite\",\n    \"build\": \"vite build\",\n    \"preview\": \"vite preview\"\n  }\n}\n",

  "src/main.js": "const root = document.getElementById('root');\nif (root) {\n  root.innerHTML = '<main><h1>Traveler Dev</h1><p>Workspace project ready.</p></main>';\n}\n"
};
'''

    path.write_text(text)

print("PASS starterProjectFiles export")
PY
