import {
  ToolLoopAgent,
  generateText,
  tool
} from "ai";

import { createOpenAICompatible } from "@ai-sdk/openai-compatible";

const GATEWAY_URL =
  process.env.TRAVELER_GATEWAY_URL ||
  "https://agent-traveler-dev2.onrender.com";

const GATEWAY_API_KEY =
  process.env.GATEWAY_API_KEY;

const MODEL =
  process.env.TRAVELER_MODEL ||
  "anthropic/claude-sonnet-4";

if (!GATEWAY_API_KEY) {
  throw new Error(
    "GATEWAY_API_KEY is required for live gateway inference."
  );
}

const gateway = createOpenAICompatible({
  name: "traveler-dev-gateway",
  baseURL: `${GATEWAY_URL.replace(/\/+$/, "")}/v1`,
  apiKey: GATEWAY_API_KEY,
  headers: {
    "X-API-Key": GATEWAY_API_KEY
  }
});

const inspectGateway = tool({
  description:
    "Inspect the live TRAVELER DEV FastAPI gateway.",
  inputSchema: {
    type: "object",
    properties: {},
    additionalProperties: false
  },
  execute: async () => {
    const response = await fetch(
      `${GATEWAY_URL.replace(/\/+$/, "")}/health`
    );

    if (!response.ok) {
      throw new Error(
        `Gateway health failed: HTTP ${response.status}`
      );
    }

    return await response.json();
  }
});

const getGatewayModels = tool({
  description:
    "Retrieve models exposed by the TRAVELER DEV gateway.",
  inputSchema: {
    type: "object",
    properties: {},
    additionalProperties: false
  },
  execute: async () => {
    const response = await fetch(
      `${GATEWAY_URL.replace(/\/+$/, "")}/v1/models`,
      {
        headers: {
          "X-API-Key": GATEWAY_API_KEY
        }
      }
    );

    if (!response.ok) {
      throw new Error(
        `Gateway models failed: HTTP ${response.status}`
      );
    }

    return await response.json();
  }
});

export const travelerAgent = new ToolLoopAgent({
  model: gateway.chat(MODEL),
  instructions: `
You are the TRAVELER DEV production coding agent.

Architecture:

TRAVELER DEV Web UI
        ↓
Vercel AI SDK ToolLoopAgent
        ↓
OpenAI-compatible FastAPI gateway
        ↓
OpenRouter
        ↓
Anthropic Claude

The FastAPI gateway owns all provider credentials.

Never request, expose, print, store, or hard-code:
OPENROUTER_API_KEY
GROQ_API_KEY
CEREBRAS_API_KEY
SURGE_TOKEN

Use production tools only.

Inspect before modifying.
Preserve existing functionality.
Make real production changes.
Validate changed files.
Run relevant tests.
Build applications before declaring success.
Generate real downloadable application artifacts.
Never claim success unless the operation actually succeeded.

Deployment must require explicit user confirmation.
`,
  tools: {
    inspect_gateway: inspectGateway,
    get_gateway_models: getGatewayModels
  }
});

export async function runTravelerAgent(prompt) {
  return await travelerAgent.generate({
    prompt
  });
}

export async function testGatewayInference() {
  const result = await generateText({
    model: gateway.chat(MODEL),
    system:
      "You are performing a production gateway connectivity test.",
    prompt:
      "Return exactly: TRAVELER DEV VERCEL AGENT INFERENCE PASS",
    maxOutputTokens: 64
  });

  return result.text;
}
