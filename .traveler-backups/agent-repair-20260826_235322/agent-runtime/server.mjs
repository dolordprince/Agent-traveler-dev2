import http from "node:http";
import { runAgent } from "./agent.mjs";

const PORT = Number(process.env.PORT || 8787);

function json(res, status, payload) {
  const body = JSON.stringify(payload);

  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body)
  });

  res.end(body);
}

async function readBody(req) {
  const chunks = [];

  for await (const chunk of req) {
    chunks.push(chunk);

    const size = chunks.reduce(
      (total, item) => total + item.length,
      0
    );

    if (size > 1024 * 1024) {
      throw new Error("Request body exceeds 1 MB");
    }
  }

  const raw = Buffer.concat(chunks).toString("utf8");

  if (!raw) {
    return {};
  }

  return JSON.parse(raw);
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "GET" && req.url === "/health") {
      return json(res, 200, {
        status: "ok",
        service: "traveler-dev-vercel-agent",
        runtime: "vercel-ai-sdk",
        gateway: process.env.TRAVELER_GATEWAY_URL ||
          "https://agent-traveler-dev2.onrender.com",
        model: process.env.TRAVELER_AGENT_MODEL ||
          "anthropic/claude-sonnet-4"
      });
    }

    if (req.method === "POST" && req.url === "/agent/run") {
      const body = await readBody(req);

      if (typeof body.prompt !== "string" || !body.prompt.trim()) {
        return json(res, 400, {
          error: "prompt must be a non-empty string"
        });
      }

      const result = await runAgent(body.prompt);

      return json(res, 200, {
        status: "completed",
        text: result.text || "",
        steps: result.steps?.length || 0,
        finishReason: result.finishReason || null,
        usage: result.usage || null
      });
    }

    return json(res, 404, {
      error: "Not Found"
    });

  } catch (error) {
    console.error("[AGENT ERROR]", error);

    return json(res, 500, {
      error: error instanceof Error
        ? error.message
        : String(error)
    });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `TRAVELER DEV Vercel AI Agent listening on 0.0.0.0:${PORT}`
  );
});
