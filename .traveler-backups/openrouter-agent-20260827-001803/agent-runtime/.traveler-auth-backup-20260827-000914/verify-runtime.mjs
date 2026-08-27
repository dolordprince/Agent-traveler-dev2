import 'dotenv/config';
import { generateText } from 'ai';
import { createOpenAICompatible } from '@ai-sdk/openai-compatible';

const gatewayUrl =
  process.env.VERCEL_AI_GATEWAY_BASE_URL ||
  'https://ai-gateway.vercel.sh/v1';

const gatewayKey =
  process.env.AI_GATEWAY_API_KEY ||
  process.env.GATEWAY_API_KEY;

const model =
  process.env.AGENT_PRIMARY_MODEL ||
  'anthropic/claude-sonnet-4.5';

if (!gatewayKey) {
  throw new Error(
    'AI_GATEWAY_API_KEY or GATEWAY_API_KEY is required'
  );
}

const gateway = createOpenAICompatible({
  name: 'traveler-verification-gateway',
  baseURL: gatewayUrl,
  apiKey: gatewayKey,
  includeUsage: true,
});

console.log('============================================================');
console.log('TRAVELER DEV — VERCEL AI RUNTIME VERIFICATION');
console.log('============================================================');
console.log(`Gateway: ${gatewayUrl}`);
console.log(`Model:   ${model}`);
console.log();

if (typeof gateway.languageModel !== 'function') {
  throw new Error(
    'Installed @ai-sdk/openai-compatible provider does not expose languageModel().'
  );
}

const languageModel = gateway.languageModel(model);

if (!languageModel) {
  throw new Error(
    `Unable to construct language model: ${model}`
  );
}

console.log('[PASS] OpenAI-compatible language model constructed.');

const result = await generateText({
  model: languageModel,
  system:
    'You are performing a production TRAVELER DEV gateway connectivity test.',
  prompt:
    'Return exactly: TRAVELER DEV VERCEL AGENT INFERENCE PASS',
  maxOutputTokens: 64,
});

console.log('[PASS] Live model inference completed.');
console.log(`MODEL RESPONSE: ${result.text}`);

if (
  result.text.trim() !==
  'TRAVELER DEV VERCEL AGENT INFERENCE PASS'
) {
  throw new Error(
    `Unexpected inference response: ${result.text}`
  );
}

console.log();
console.log('============================================================');
console.log('TRAVELER DEV VERCEL AI RUNTIME VERIFICATION: PASS');
console.log('============================================================');
