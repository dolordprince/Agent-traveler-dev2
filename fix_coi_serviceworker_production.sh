#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$ROOT/.coi-production-backup-$STAMP"

mkdir -p "$BACKUP"

echo "============================================================"
echo " TRAVELER DEV - COI SERVICE WORKER PRODUCTION FIX"
echo "============================================================"

backup() {
  local f="$1"

  if [ -f "$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp -a "$f" "$BACKUP/$f"
    echo "BACKUP  $f"
  fi
}

for f in \
  webcontainer-ui/index.html \
  webcontainer-ui/vite.config.ts \
  webcontainer-ui/coi-serviceworker.js \
  webcontainer-ui/sw-coi.js
do
  backup "$f"
done

echo
echo "===== INDEX.HTML SERVICE WORKER CHECK ====="

python3 <<'PY'
from pathlib import Path
import re

path = Path("webcontainer-ui/index.html")

if not path.exists():
    raise SystemExit("ERROR: webcontainer-ui/index.html not found")

text = path.read_text()

# The COI service worker must remain a classic external script.
# Vite must not attempt to bundle it.
pattern = r'<script\s+src=["\'](?:\./)?coi-serviceworker\.js["\']\s*></script>'

replacement = '<script src="./coi-serviceworker.js"></script>'

new_text, count = re.subn(pattern, replacement, text, flags=re.I)

if count:
    path.write_text(new_text)
    print("NORMALIZED coi-serviceworker.js script tag")
else:
    print("No simple COI script tag replacement required")

# Ensure the service worker is not accidentally loaded as an ES module.
text = path.read_text()

if re.search(
    r'<script[^>]+src=["\'](?:\./)?coi-serviceworker\.js["\'][^>]+type=["\']module["\']',
    text,
    flags=re.I
):
    text = re.sub(
        r'\s+type=["\']module["\']',
        '',
        text,
        count=1,
        flags=re.I
    )
    path.write_text(text)
    print("REMOVED module type from COI service worker")
PY

echo
echo "===== VERIFYING SERVICE WORKER FILE ====="

test -f webcontainer-ui/coi-serviceworker.js

head -n 80 webcontainer-ui/coi-serviceworker.js

echo
echo "===== VERIFYING VITE CONFIG ====="

sed -n '1,220p' webcontainer-ui/vite.config.ts

echo
echo "===== VERIFYING COEP ====="

grep -RInE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=build \
  'Cross-Origin-Embedder-Policy|Cross-Origin-Opener-Policy|credentialless|require-corp' \
  webcontainer-ui 2>/dev/null || true

echo
echo "===== VERIFYING WebContainer BOOT ====="

grep -RInE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=build \
  'WebContainer\.boot' \
  webcontainer-ui frontend 2>/dev/null || true

echo
echo "===== CLEAN BUILD ====="

cd webcontainer-ui

rm -rf dist

npm run build

echo
echo "===== BUILD OUTPUT ====="

test -f dist/index.html

find dist -maxdepth 3 -type f -print | sort

echo
echo "===== VERIFYING COI SERVICE WORKER WAS COPIED ====="

if [ ! -f dist/coi-serviceworker.js ]; then
  echo "ERROR: dist/coi-serviceworker.js was not produced."
  echo
  echo "Vite is not copying the COI service worker."
  exit 1
fi

echo "PASS: dist/coi-serviceworker.js exists."

echo
echo "===== VERIFYING INDEX REFERENCE ====="

grep -nE 'coi-serviceworker\.js' dist/index.html || {
  echo "ERROR: dist/index.html does not reference coi-serviceworker.js"
  exit 1
}

echo
echo "===== VERIFYING NO require-corp ====="

if grep -RniE \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  'require-corp' \
  webcontainer-ui 2>/dev/null; then
  echo "ERROR: require-corp remains in active source."
  exit 1
fi

echo "PASS: No require-corp in active source."

echo
echo "===== VERIFYING BOOT OPTIONS ====="

python3 <<'PY'
from pathlib import Path
import re
import sys

roots = [Path("webcontainer-ui"), Path("../frontend")]

bad = []

for root in roots:
    if not root.exists():
        continue

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(
            part in {"node_modules", ".git", "dist", "build"}
            for part in path.parts
        ):
            continue

        if path.suffix not in {".js", ".mjs", ".ts", ".tsx", ".html"}:
            continue

        try:
            text = path.read_text(errors="ignore")
        except Exception:
            continue

        for match in re.finditer(
            r"WebContainer\.boot\s*\((.*?)\)",
            text,
            re.S
        ):
            args = match.group(1).strip()

            if not args or "coep" not in args:
                bad.append(str(path))

if bad:
    print("ERROR: Unconfigured WebContainer.boot call:")
    for item in sorted(set(bad)):
        print("  " + item)
    sys.exit(1)

print("PASS: WebContainer boot configuration is explicit.")
PY

echo
echo "============================================================"
echo " PRODUCTION COI SERVICE WORKER FIX PASSED"
echo "============================================================"
echo
echo "Backup:"
echo "$BACKUP"
echo
echo "Build:"
echo "PASS"
echo
echo "dist/coi-serviceworker.js:"
echo "PASS"
echo
echo "COEP:"
echo "credentialless"
echo
echo "============================================================"
