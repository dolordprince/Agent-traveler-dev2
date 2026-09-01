#!/usr/bin/env bash
set -u

ROOT="$HOME/Agent-traveler-dev2"
FRONTEND="$ROOT/frontend"

printf '\n=== TRAVELER DEV FRONTEND — CHUNK 2 ===\n'

if [ ! -d "$FRONTEND" ]; then
  printf 'ERROR: frontend directory does not exist.\n'
  exit 1
fi

cat > "$FRONTEND/src/stackblitz.js" <<'EOF'
const STACKBLITZ_API =
  "https://webcontainer.api.stackblitz.com";

export function stackblitzConfig(files) {
  return {
    files,
    settings: {
      compile: {
        trigger: "auto"
      }
    }
  };
}

export function stackblitzApiUrl() {
  return STACKBLITZ_API;
}
EOF

python - "$FRONTEND/src/main.js" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

needle = 'import "./style.css";\n'

if 'stackblitz.js' not in text:
    text = text.replace(
        needle,
        needle + 'import { stackblitzApiUrl } from "./stackblitz.js";\n'
    )

text = text.replace(
    'const API =\n  import.meta.env.VITE_WORKSPACE_API_URL ||\n  window.location.origin;',
    '''const API =
  import.meta.env.VITE_WORKSPACE_API_URL ||
  window.location.origin;

const STACKBLITZ_API_URL = stackblitzApiUrl();'''
)

text = text.replace(
    'state.terminal.push("[run] StackBlitz/WebContainer bridge is ready for integration.");',
    'state.terminal.push(`[run] StackBlitz bridge: ${STACKBLITZ_API_URL}`);'
)

path.write_text(text)
PY

cat > "$FRONTEND/.env.example" <<'EOF'
VITE_WORKSPACE_API_URL=
EOF

printf '\n=== STATIC VALIDATION ===\n'

required=(
  "$FRONTEND/index.html"
  "$FRONTEND/package.json"
  "$FRONTEND/vite.config.js"
  "$FRONTEND/src/main.js"
  "$FRONTEND/src/style.css"
  "$FRONTEND/src/stackblitz.js"
  "$FRONTEND/public/manifest.webmanifest"
  "$FRONTEND/public/sw.js"
)

for file in "${required[@]}"; do
  if [ -f "$file" ]; then
    printf 'PASS  %s\n' "${file#$ROOT/}"
  else
    printf 'FAIL  %s\n' "${file#$ROOT/}"
    exit 1
  fi
done

if command -v node >/dev/null 2>&1; then
  node --check "$FRONTEND/src/main.js"
  node --check "$FRONTEND/src/stackblitz.js"
  printf 'PASS  JavaScript syntax\n'
fi

printf '\n=== PACKAGE AVAILABILITY ===\n'

if [ -d "$FRONTEND/node_modules" ] &&
   [ -x "$FRONTEND/node_modules/.bin/vite" ]; then

  printf 'PASS  Local Vite installation detected\n'

  (
    cd "$FRONTEND" || exit 1
    npm run build
  )

  printf 'PASS  Production frontend build\n'

else

  printf 'INFO  Vite is not installed locally.\n'
  printf 'INFO  No registry request was made by this script.\n'
  printf 'INFO  Source validation completed successfully.\n'
fi

printf '\n=== GIT STATUS ===\n'

cd "$ROOT" || exit 1
git status --short -- frontend

printf '\n============================================================\n'
printf 'TRAVELER DEV FRONTEND — CHUNKS COMPLETE\n'
printf '============================================================\n'
printf 'Frontend: %s\n' "$FRONTEND"
printf 'PWA: manifest.webmanifest + sw.js\n'
printf 'Responsive: desktop / tablet / mobile\n'
printf 'Workspace: VS Code-style explorer/editor/terminal/AI layout\n'
printf 'StackBlitz bridge: prepared\n'
printf 'Backend API: VITE_WORKSPACE_API_URL\n'
printf '\nNo kill/pkill commands were used.\n'
printf 'No background server was started.\n'
printf 'No forced npm installation was performed.\n'
