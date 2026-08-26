import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { ToolLoopAgent } from "ai";

const gatewayUrl =
  process.env.TRAVELER_GATEWAY_URL ||
  "https://agent-traveler-dev2.onrender.com";

const model =
  process.env.TRAVELER_MODEL ||
  "anthropic/claude-sonnet-4";

console.log("============================================================");
console.log("TRAVELER DEV — VERCEL AI RUNTIME VERIFICATION");
console.log("============================================================");

const gateway = createOpenAICompatible({
  name: "traveler-dev-gateway",
  baseURL: `${gatewayUrl.replace(/\/+$/, "")}/v1`,
  apiKey: process.env.GATEWAY_API_KEY || "runtime-validation",
  headers: {
    "X-API-Key": process.env.GATEWAY_API_KEY || "runtime-validation"
  }
});

new ToolLoopAgent({
  model: gateway.chat(model),
  instructions: "Production TRAVELER DEV coding agent."
});

console.log("[PASS] AI SDK import");
console.log("[PASS] ToolLoopAgent import");
console.log("[PASS] OpenAI-compatible provider");
console.log("[PASS] ToolLoopAgent construction");
console.log("[PASS] Gateway configuration");
console.log(`Gateway: ${gatewayUrl}`);
console.log(`Model: ${model}`);

if (process.env.GATEWAY_API_KEY) {
  console.log("[PASS] Gateway credential available");
} else {
  console.log("[INFO] Gateway credential is not present locally");
  console.log("[INFO] This verification does not perform inference");
}

console.log("OVERALL: PASS");
