import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Native Cross-Origin Isolation Headers for WebContainers
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  next();
});

const staticPath = path.existsSync(path.join(__dirname, 'webcontainer-ui')) 
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
