#!/usr/bin/env bash
set -euo pipefail

TARGET_REPO="https://github.com/dolordprince/Mynewnotebookstudio.git"
APP_NAME="TRAVELER-DEV"

echo "=== [1/5] Updating Git Remote to Mynewnotebookstudio ==="
cd /root/Agent-traveler-dev2

git remote remove origin || true
git remote add origin "$TARGET_REPO"

echo "=== [2/5] Configuring Vite for Relative Base Path (GitHub Pages Compatibility) ==="
cat << 'VITEEOF' > vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './', // Ensures assets load correctly on GitHub Pages
  server: {
    headers: {
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin'
    }
  }
})
VITEEOF

echo "=== [3/5] Setting up GitHub Actions Deployment Workflow ==="
mkdir -p .github/workflows public
touch public/.nojekyll

cat << 'GHAEOF' > .github/workflows/deploy.yml
name: Deploy TRAVELER-DEV to GitHub Pages

on:
  push:
    branches: ["main", "master"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci || npm install

      - name: Build site
        run: npm run build

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: './dist'

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
GHAEOF

echo "=== [4/5] Creating Initial README & Committing Workspace ==="
echo "# Mynewnotebookstudio - ${APP_NAME}" > README.md

git branch -M main
git add .
git commit -m "feat: setup TRAVELER-DEV notebook workspace with WebContainer API & GitHub Pages" || echo "Nothing new to commit"

echo "=== [5/5] Pushing to GitHub (dolordprince/Mynewnotebookstudio) ==="
git push -u origin main --force

echo ""
echo "=== SUCCESS! Workspace pushed to $TARGET_REPO ==="
