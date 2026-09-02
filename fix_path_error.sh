#!/usr/bin/env bash
set -euo pipefail

echo "=== Fixing server.js fs import ==="
cat << 'SERVEREOF' > server.js
import express from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Cross-Origin Isolation Headers required for WebContainer
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  next();
});

const staticPath = fs.existsSync(path.join(__dirname, 'webcontainer-ui')) 
  ? path.join(__dirname, 'webcontainer-ui') 
  : __dirname;

app.use(express.static(staticPath));

app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

const PORT = process.env.PORT || 7860;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with COOP/COEP enabled.`);
});
SERVEREOF

echo "=== Committing and Pushing Fix to Hugging Face ==="
git add server.js
git commit -m "fix(server): replace path.existsSync with fs.existsSync" || true
git push hf main --force || git push origin main --force

echo "=== Deploy Fix Complete ==="
