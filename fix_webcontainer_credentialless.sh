#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$ROOT/.webcontainer-fix-backup-$STAMP"

echo "============================================================"
echo " TRAVELER DEV - WebContainer COEP PRODUCTION FIX"
echo "============================================================"
echo "Project : $ROOT"
echo "Backup  : $BACKUP"
echo

mkdir -p "$BACKUP"

backup_file() {
  local file="$1"

  if [ -f "$file" ]; then
    mkdir -p "$BACKUP/$(dirname "$file")"
    cp -a "$file" "$BACKUP/$file"
    echo "BACKUP  $file"
  fi
}

replace_file() {
  local file="$1"

  if [ -f "$file" ]; then
    python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

original = text

# WebContainer must receive the same COEP mode used by the
# cross-origin-isolated application.
text = text.replace(
    "WebContainer.boot()",
    'WebContainer.boot({ coep: "credentialless" })'
)

# Handle code that may use a different capitalization/reference.
text = text.replace(
    "Webcontainer.boot()",
    'Webcontainer.boot({ coep: "credentialless" })'
)

# Standardize explicit HTTP header configuration.
text = text.replace(
    "Cross-Origin-Embedder-Policy: require-corp",
    "Cross-Origin-Embedder-Policy: credentialless"
)

text = text.replace(
    '"Cross-Origin-Embedder-Policy": "require-corp"',
    '"Cross-Origin-Embedder-Policy": "credentialless"'
)

text = text.replace(
    "'Cross-Origin-Embedder-Policy': 'require-corp'",
    "'Cross-Origin-Embedder-Policy': 'credentialless'"
)

text = text.replace(
    "setHeader('Cross-Origin-Embedder-Policy', 'require-corp')",
    "setHeader('Cross-Origin-Embedder-Policy', 'credentialless')"
)

text = text.replace(
    'setHeader("Cross-Origin-Embedder-Policy", "require-corp")',
    'setHeader("Cross-Origin-Embedder-Policy", "credentialless")'
)

text = text.replace(
    'h.set("Cross-Origin-Embedder-Policy", "require-corp")',
    'h.set("Cross-Origin-Embedder-Policy", "credentialless")'
)

text = text.replace(
    'newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp")',
    'newHeaders.set("Cross-Origin-Embedder-Policy", "credentialless")'
)

path.write_text(text)

if text != original:
    print(f"UPDATED {path}")
else:
    print(f"UNCHANGED {path}")
PY
  fi
}

echo
echo "===== BACKING UP APPLICATION FILES ====="

FILES=(
  "webcontainer-ui/src/main.ts"
  "webcontainer-ui/index.html"
  "webcontainer-ui/vite.config.ts"
  "webcontainer-ui/vercel.json"
  "webcontainer-ui/sw-coi.js"
  "webcontainer-ui/coi-serviceworker.js"
  "frontend/src/stackblitz.js"
  "server.js"
  "coi-serviceworker.js"
)

for file in "${FILES[@]}"; do
  backup_file "$file"
done

echo
echo "===== PATCHING APPLICATION SOURCES ====="

for file in "${FILES[@]}"; do
  replace_file "$file"
done

echo
echo "===== ENSURING WebContainer BOOT IS EXPLICIT ====="

python3 <<'PY'
from pathlib import Path

targets = [
    Path("webcontainer-ui/src/main.ts"),
    Path("webcontainer-ui/index.html"),
    Path("frontend/src/stackblitz.js"),
]

for path in targets:
    if not path.exists():
        continue

    text = path.read_text()

    # Catch whitespace variations while preserving the surrounding code.
    text = text.replace(
        "WebContainer.boot();",
        'WebContainer.boot({ coep: "credentialless" });'
    )

    text = text.replace(
        "WebContainer.boot()",
        'WebContainer.boot({ coep: "credentialless" })'
    )

    path.write_text(text)
    print(f"CHECKED {path}")
PY

echo
echo "===== VITE CONFIGURATION ====="

if [ -f webcontainer-ui/vite.config.ts ]; then
  cat > webcontainer-ui/vite.config.ts <<'VITE'
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    port: 5173,
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "credentialless"
    }
  },

  preview: {
    host: "0.0.0.0",
    port: 4173,
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "credentialless"
    }
  }
});
VITE
  echo "UPDATED webcontainer-ui/vite.config.ts"
fi

echo
echo "===== VERCEL HEADERS ====="

if [ -f webcontainer-ui/vercel.json ]; then
  python3 - <<'PY'
from pathlib import Path
import json

path = Path("webcontainer-ui/vercel.json")
data = json.loads(path.read_text())

def walk(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "value" and item == "require-corp":
                value[key] = "credentialless"
            else:
                walk(item)
    elif isinstance(value, list):
        for item in value:
            walk(item)

walk(data)

path.write_text(json.dumps(data, indent=2) + "\n")
print("UPDATED webcontainer-ui/vercel.json")
PY
fi

echo
echo "===== PRODUCTION SERVER HEADERS ====="

if [ -f server.js ]; then
  grep -nE \
    'Cross-Origin-Opener-Policy|Cross-Origin-Embedder-Policy' \
    server.js || true
fi

echo
echo "===== VERIFYING WebContainer BOOT CALLS ====="

grep -RInE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=build \
  'WebContainer\.boot' \
  webcontainer-ui frontend 2>/dev/null || true

echo
echo "===== VERIFYING COEP ====="

grep -RInE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=build \
  'Cross-Origin-Embedder-Policy|credentialless|require-corp' \
  webcontainer-ui frontend server.js coi-serviceworker.js 2>/dev/null || true

echo
echo "===== CHECKING FOR REMAINING require-corp IN ACTIVE APP ====="

if grep -RniE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=build \
  'require-corp' \
  webcontainer-ui frontend server.js coi-serviceworker.js 2>/dev/null; then

  echo
  echo "ERROR: Active application still contains require-corp."
  exit 1
else
  echo "PASS: No require-corp remains in active WebContainer application files."
fi

echo
echo "===== CHECKING FOR UNCONFIGURED WebContainer BOOT ====="

python3 <<'PY'
from pathlib import Path
import re
import sys

roots = [
    Path("webcontainer-ui"),
    Path("frontend"),
]

bad = []

for root in roots:
    if not root.exists():
        continue

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(part in {"node_modules", ".git", "dist", "build"} for part in path.parts):
            continue

        if path.suffix not in {".js", ".mjs", ".ts", ".tsx", ".html"}:
            continue

        try:
            text = path.read_text(errors="ignore")
        except Exception:
            continue

        for match in re.finditer(r"WebContainer\.boot\s*\((.*?)\)", text, re.S):
            args = match.group(1).strip()

            if not args or "coep" not in args:
                bad.append((str(path), match.start()))

if bad:
    print("ERROR: Unconfigured WebContainer.boot call(s) found:")
    for path, _ in bad:
        print("  " + path)
    sys.exit(1)

print("PASS: WebContainer boot calls specify COEP.")
PY

echo
echo "===== TYPESCRIPT/JAVASCRIPT SYNTAX PRECHECK ====="

if [ -f webcontainer-ui/package.json ]; then
  node -e '
const p=require("./webcontainer-ui/package.json");
console.log("webcontainer-ui:", p.name || "unnamed");
console.log("scripts:", JSON.stringify(p.scripts || {}, null, 2));
'
fi

echo
echo "===== BUILD ====="

if [ -f webcontainer-ui/package.json ]; then
  cd webcontainer-ui

  if [ -f package-lock.json ]; then
    npm install
  else
    npm install
  fi

  npm run build

  cd "$ROOT"
fi

echo
echo "============================================================"
echo " PRODUCTION FIX COMPLETED"
echo "============================================================"
echo
echo "Backup:"
echo "$BACKUP"
echo
echo "Next:"
echo "1. Review git diff."
echo "2. Commit the production changes."
echo "3. Push the deployment."
echo
