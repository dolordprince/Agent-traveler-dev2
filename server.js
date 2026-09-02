import express from "express";
import { createServer } from "http";
import { existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { createProxyMiddleware } from "http-proxy-middleware";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = parseInt(process.env.PORT || "7860", 10);
const FASTAPI_URL = process.env.FASTAPI_INTERNAL_URL || "http://127.0.0.1:7861";

const app = express();

// WebContainer required headers
app.use((req, res, next) => {
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
  res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS,PATCH");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type,Authorization");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

// Proxy /api and /v1 to FastAPI
app.use("/api", createProxyMiddleware({
  target: FASTAPI_URL, changeOrigin: true,
  on: { error: (err, req, res) => {
    console.error("[proxy]", err.message);
    res.status(502).json({ error: "Backend unavailable" });
  }},
}));
app.use("/v1",  createProxyMiddleware({ target: FASTAPI_URL, changeOrigin: true }));
app.use("/ws",  createProxyMiddleware({ target: FASTAPI_URL, changeOrigin: true, ws: true }));

// Serve UI
const UI_DIST = join(__dirname, "webcontainer-ui", "dist");
const UI_ROOT = existsSync(join(UI_DIST, "index.html")) ? UI_DIST
              : join(__dirname, "webcontainer-ui");

console.log(`[server] UI: ${UI_ROOT}`);
app.use(express.static(UI_ROOT));
app.get("*", (req, res) => {
  const idx = join(UI_ROOT, "index.html");
  existsSync(idx) ? res.sendFile(idx)
                  : res.status(404).send("Run: cd webcontainer-ui && npm run build");
});

createServer(app).listen(PORT, "0.0.0.0", () => {
  console.log(`[TRAVELER DEV] http://0.0.0.0:${PORT} → FastAPI ${FASTAPI_URL}`);
});
