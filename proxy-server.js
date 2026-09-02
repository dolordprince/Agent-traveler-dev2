import express from "express";
import https from "https";

const app = express();
app.use(express.json());

const GROQ_KEY = process.env.GROQ_API_KEY || "";

if (!GROQ_KEY) {
  console.error("❌ GROQ_API_KEY not set");
  process.exit(1);
}

app.get("/health", (req, res) => res.json({ status: "ok", proxy: "groq" }));

app.get("/v1/models", (req, res) => res.json({
  object: "list",
  data: [{ id: "openai/claude-opus-4", object: "model" }]
}));

app.post("/v1/chat/completions", (req, res) => {
  const body = JSON.stringify({
    model: "llama3-70b-8192",
    messages: req.body.messages,
    temperature: req.body.temperature || 0.1,
    max_tokens: req.body.max_tokens || 4096,
  });

  console.log("[proxy] → Groq llama3-70b-8192 msgs:", req.body.messages.length);

  const options = {
    hostname: "api.groq.com",
    path: "/openai/v1/chat/completions",
    method: "POST",
    headers: {
      "Authorization": "Bearer " + GROQ_KEY,
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    let data = "";
    proxyRes.on("data", c => data += c);
    proxyRes.on("end", () => {
      console.log("[proxy] Groq status:", proxyRes.statusCode);
      try {
        res.status(proxyRes.statusCode).json(JSON.parse(data));
      } catch {
        res.status(500).json({ error: "Invalid JSON from Groq", raw: data.slice(0,200) });
      }
    });
  });

  proxyReq.on("error", (e) => {
    console.error("[proxy] network error:", e.message);
    res.status(502).json({ error: e.message });
  });

  proxyReq.write(body);
  proxyReq.end();
});

app.listen(3456, () => {
  console.log("✅ Proxy :3456 → Groq llama3-70b-8192");
});
