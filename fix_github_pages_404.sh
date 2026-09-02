#!/usr/bin/env bash
set -euo pipefail

cd /root/Agent-traveler-dev2

echo "=== [1/3] Updating Vite base path to /Mynewnotebookstudio/ ==="
cat << 'VITEEOF' > vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/Mynewnotebookstudio/', // Exact GitHub Pages subpath
  server: {
    headers: {
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin'
    }
  }
})
VITEEOF

echo "=== [2/3] Adding 404.html fallback and .nojekyll for SPA routing ==="
mkdir -p public
touch public/.nojekyll

# Copy index.html as 404.html after build via npm script or post-build hook
cat << 'PKGEOFF' > post_build.sh
#!/usr/bin/env bash
cp dist/index.html dist/404.html
PKGEOFF
chmod +x post_build.sh

echo "=== [3/3] Committing and Pushing Fix ==="
git add vite.config.js public/.nojekyll post_build.sh
git commit -m "fix: set correct vite base path /Mynewnotebookstudio/ and SPA routing" || echo "Nothing new to commit"
git push origin main

echo "=== DONE! GitHub Actions will redeploy momentarily. ==="
