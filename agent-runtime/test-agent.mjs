import { testGatewayInference } from "./agent.mjs";

console.log("============================================================");
console.log("TRAVELER DEV — LIVE VERCEL AGENT INFERENCE");
console.log("============================================================");

try {
  const text = await testGatewayInference();

  if (text.trim() !== "TRAVELER DEV VERCEL AGENT INFERENCE PASS") {
    console.error("[FAIL] Unexpected model response:");
    console.error(text);
    process.exit(1);
  }

  console.log("[PASS] Real authenticated inference");
  console.log("[PASS] FastAPI gateway reached");
  console.log("[PASS] OpenAI-compatible route reached");
  console.log("[PASS] Production model response validated");
  console.log("OVERALL: PASS");
} catch (error) {
  console.error("[FAIL] Live inference failed");
  console.error(error?.message || error);
  process.exit(1);
}
