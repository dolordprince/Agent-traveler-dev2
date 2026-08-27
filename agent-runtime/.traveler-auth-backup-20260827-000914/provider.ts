import { createOpenAICompatible } from '@ai-sdk/openai-compatible';

const gatewayUrl =
  process.env.VERCEL_AI_GATEWAY_BASE_URL ||
  'https://ai-gateway.vercel.sh/v1';

const gatewayKey =
  process.env.AI_GATEWAY_API_KEY ||
  process.env.GATEWAY_API_KEY;

if (!gatewayKey) {
  throw new Error(
    'AI_GATEWAY_API_KEY or GATEWAY_API_KEY is required'
  );
}

export const gateway = createOpenAICompatible({
  name: 'vercel-gateway',
  baseURL: gatewayUrl,
  apiKey: gatewayKey,
  includeUsage: true,
});

export const PRIMARY_AGENT_MODEL =
  process.env.AGENT_PRIMARY_MODEL ||
  'anthropic/claude-sonnet-4.5';

export const FALLBACK_AGENT_MODELS: string[] = (
  process.env.AGENT_FALLBACK_MODELS ||
  'openai/gpt-5.4'
)
  .split(',')
  .map((value: string) => value.trim())
  .filter(Boolean);

export function getAgentModel(modelId: string = PRIMARY_AGENT_MODEL) {
  return gateway.languageModel(modelId);
}

export function getConfiguredAgentModels() {
  return [
    PRIMARY_AGENT_MODEL,
    ...FALLBACK_AGENT_MODELS,
  ];
}
