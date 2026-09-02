import express from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Permanent fix for nested iframe WebContainers (Hugging Face / StackBlitz)
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Access-Control-Allow-Origin', '*');
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
  console.log(`Server running on port ${PORT} with Credentialless COOP/COEP.`);
});
