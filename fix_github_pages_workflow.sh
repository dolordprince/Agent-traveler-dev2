#!/usr/bin/env bash
set -euo pipefail

cd /root/Agent-traveler-dev2

echo "=== Updating Vite Base Path ==="
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

echo "=== Updating GitHub Actions Workflow ==="
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
          node-version: 22
          cache: 'npm'

      - name: Install dependencies
        run: npm ci || npm install

      - name: Build site
        run: npm run build

      - name: Copy index.html to 404.html for SPA routing
        run: cp dist/index.html dist/404.html

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

git add vite.config.js public/.nojekyll .github/workflows/deploy.yml
git commit -m "fix: set GitHub Actions source base path and routing" || true
git push origin main

echo "=== Done! ==="
