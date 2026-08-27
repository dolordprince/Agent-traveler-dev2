#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${HOME}/traveler-cloudflare-ai"
WORKER_NAME="opencode"

echo "============================================================"
echo " TRAVELER DEV — CLOUDFLARE WORKERS AI"
echo "============================================================"

command -v node >/dev/null 2>&1 || {
  echo "[FAIL] Node.js is not installed"
  exit 1
}

command -v npm >/dev/null 2>&1 || {
  echo "[FAIL] npm is not installed"
  exit 1
}

echo "[PASS] Node.js: $(node --version)"
echo "[PASS] npm: $(npm --version)"

if ! command -v npx >/dev/null 2>&1; then
  echo "[FAIL] npx is not available"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/src"

cd "$APP_DIR"

echo "[PASS] Working directory: $APP_DIR"

cat > package.json <<'PACKAGE_EOF'
{
  "name": "traveler-dev-cloudflare-ai",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "typecheck": "tsc --noEmit",
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20260826.0",
    "typescript": "^5.9.3",
    "wrangler": "^4.126.0"
  }
}
PACKAGE_EOF

cat > tsconfig.json <<'TS_EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "types": [
      "@cloudflare/workers-types"
    ]
  },
  "include": [
    "src/**/*.ts"
  ]
}
TS_EOF

cat > wrangler.jsonc <<'WRANGLER_EOF'
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "opencode",
  "main": "src/index.ts",
  "compatibility_date": "2026-08-26",

  "ai": {
    "binding": "AI"
  },

  "observability": {
    "logs": {
      "enabled": true
    },
    "traces": {
      "enabled": true
    }
  }
}
WRANGLER_EOF

cat > src/index.ts <<'WORKER_EOF'
interface Env {
  AI: Ai;
}

const MODEL = "@cf/zai-org/glm-4.7-flash";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, Accept",
  "Access-Control-Max-Age": "86400"
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function errorResponse(
  message: string,
  status: number,
  extra: Record<string, unknown> = {}
): Response {
  return json(
    {
      error: {
        message,
        ...extra
      }
    },
    status
  );
}

function getTextFromResult(result: unknown): string {
  if (
    typeof result === "object" &&
    result !== null &&
    "response" in result
  ) {
    const response = (result as { response?: unknown }).response;

    if (typeof response === "string") {
      return response;
    }
  }

  if (typeof result === "string") {
    return result;
  }

  return JSON.stringify(result);
}

async function runModel(
  env: Env,
  body: Record<string, unknown>
): Promise<unknown> {
  const input: Record<string, unknown> = {
    messages: body.messages
  };

  const allowedParameters = [
    "temperature",
    "top_p",
    "max_tokens",
    "max_completion_tokens",
    "tools",
    "tool_choice"
  ];

  for (const key of allowedParameters) {
    if (body[key] !== undefined) {
      input[key] = body[key];
    }
  }

  return env.AI.run(
    MODEL as Parameters<Ai["run"]>[0],
    input as never
  );
}

async function chatCompletions(
  request: Request,
  env: Env
): Promise<Response> {
  let body: Record<string, unknown>;

  try {
    body = await request.json();
  } catch {
    return errorResponse(
      "Request body must contain valid JSON.",
      400
    );
  }

  if (!Array.isArray(body.messages)) {
    return errorResponse(
      "messages must be an array.",
      400
    );
  }

  if (body.messages.length === 0) {
    return errorResponse(
      "messages cannot be empty.",
      400
    );
  }

  if (
    body.model !== undefined &&
    body.model !== MODEL
  ) {
    return errorResponse(
      `Unsupported model. Use ${MODEL}.`,
      400
    );
  }

  try {
    const result = await runModel(env, body);
    const content = getTextFromResult(result);

    const id = `chatcmpl-${crypto.randomUUID()}`;
    const created = Math.floor(Date.now() / 1000);

    if (body.stream === true) {
      const encoder = new TextEncoder();

      const stream = new ReadableStream({
        start(controller) {
          const firstChunk = {
            id,
            object: "chat.completion.chunk",
            created,
            model: MODEL,
            choices: [
              {
                index: 0,
                delta: {
                  role: "assistant",
                  content
                },
                finish_reason: null
              }
            ]
          };

          const finalChunk = {
            id,
            object: "chat.completion.chunk",
            created,
            model: MODEL,
            choices: [
              {
                index: 0,
                delta: {},
                finish_reason: "stop"
              }
            ]
          };

          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify(firstChunk)}\n\n`
            )
          );

          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify(finalChunk)}\n\n`
            )
          );

          controller.enqueue(
            encoder.encode("data: [DONE]\n\n")
          );

          controller.close();
        }
      });

      return new Response(stream, {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "text/event-stream; charset=utf-8",
          "Cache-Control": "no-cache, no-transform",
          Connection: "keep-alive"
        }
      });
    }

    return json({
      id,
      object: "chat.completion",
      created,
      model: MODEL,
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content
          },
          finish_reason: "stop"
        }
      ]
    });
  } catch (error) {
    console.error("Workers AI failure:", error);

    return errorResponse(
      "Cloudflare Workers AI inference failed.",
      502,
      {
        provider: "cloudflare-workers-ai",
        model: MODEL
      }
    );
  }
}

export default {
  async fetch(
    request: Request,
    env: Env
  ): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS
      });
    }

    if (
      request.method === "GET" &&
      url.pathname === "/health"
    ) {
      return json({
        status: "healthy",
        service: "traveler-dev-ai-gateway",
        provider: "cloudflare-workers-ai",
        model: MODEL
      });
    }

    if (
      request.method === "GET" &&
      url.pathname === "/v1/models"
    ) {
      return json({
        object: "list",
        data: [
          {
            id: MODEL,
            object: "model",
            owned_by: "zai-org",
            context_window: 131072,
            capabilities: [
              "chat",
              "reasoning",
              "tool_calling",
              "streaming"
            ]
          }
        ]
      });
    }

    if (
      request.method === "POST" &&
      url.pathname === "/v1/chat/completions"
    ) {
      return chatCompletions(request, env);
    }

    return errorResponse(
      "Not found.",
      404
    );
  }
};
WORKER_EOF

echo "[PASS] Production Worker source created"

echo
echo "Installing dependencies..."
npm install

echo
echo "Running TypeScript validation..."
npm run typecheck

echo
echo "Checking Wrangler authentication..."

if ! npx wrangler whoami; then
  echo
  echo "[FAIL] Wrangler is not authenticated."
  echo
  echo "Run:"
  echo "  npx wrangler login"
  echo
  exit 1
fi

echo
echo "Deploying Worker..."
npm run deploy

echo
echo "============================================================"
echo " DEPLOYMENT FINISHED"
echo "============================================================"
echo
echo "Existing production hostname:"
echo "https://opencode.personaldolor.workers.dev"
echo
echo "Health:"
echo "https://opencode.personaldolor.workers.dev/health"
echo
echo "Models:"
echo "https://opencode.personaldolor.workers.dev/v1/models"
echo
echo "Chat:"
echo "https://opencode.personaldolor.workers.dev/v1/chat/completions"
echo

echo "Testing health endpoint..."
curl -fsS \
  "https://opencode.personaldolor.workers.dev/health"

echo
echo
echo "Testing model endpoint..."
curl -fsS \
  "https://opencode.personaldolor.workers.dev/v1/models"

echo
echo
echo "Testing real Workers AI inference..."

curl -fsS \
  -X POST \
  "https://opencode.personaldolor.workers.dev/v1/chat/completions" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "@cf/zai-org/glm-4.7-flash",
    "messages": [
      {
        "role": "user",
        "content": "Reply with exactly: TRAVELER DEV CLOUDFLARE AI ONLINE"
      }
    ]
  }'

echo
echo
echo "============================================================"
echo " REAL INFERENCE TEST PASSED"
echo "============================================================"
