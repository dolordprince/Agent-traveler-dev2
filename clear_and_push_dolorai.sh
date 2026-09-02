#!/usr/bin/env bash
set -euo pipefail

cd /root/Agent-traveler-dev2

echo "=== [1/3] Clearing Stored Git Credentials ==="
# Unset stored credentials in git config
git config --global --unset-all credential.helper || true
git config --system --unset-all credential.helper || true
git config --local --unset-all credential.helper || true

# Set identity to Dolorai
git config user.name "Dolorai"
git config user.email "dolorai@users.noreply.github.com"

echo "=== [2/3] Setting Clean Remote URL ==="
git remote set-url origin "https://github.com/Dolorai/my-notebook-workspace-.git"

echo "=== [3/3] Ready to Push ==="
echo "Run the command below. Git will now prompt you for your GitHub username and password/token:"
echo ""
echo "git push -u origin main --force"
echo ""
