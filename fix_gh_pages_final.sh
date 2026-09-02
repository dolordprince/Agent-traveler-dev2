#!/usr/bin/env bash
set -euo pipefail

cd /root/Agent-traveler-dev2

echo "=== [1/2] Updating Vite Base & Building ==="
cat << 'VITEEOF' > vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/Mynewnotebookstudio/',
})
VITEEOF

mkdir -p public
touch public/.nojekyll

git add vite.config.js public/.nojekyll
git commit -m "fix: set correct base path for GitHub Pages actions deployment" || true
git push origin main

echo "=== [2/2] Pushed to main ==="
