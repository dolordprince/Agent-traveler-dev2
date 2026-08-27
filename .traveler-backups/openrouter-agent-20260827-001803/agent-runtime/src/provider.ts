import { createOpenAICompatible } from '@ai-sdk/openai-compatible';

const gatewayUrl =
  process.env.VERCEL_AI_GATEWAY_BASE_URL ||
  process.env.TRAVELER_GATEWAY_URL ||
  'http://127.0.0.1:7860/v1';

const gatewayKey =
  process.env.AI_GATEWAY_API_KEY ||
  process.env.GATEWAY_API_KEY ||
  '';

export const gateway = createOpenAICompatible({
  name: 'traveler-gateway',
  baseURL: gatewayUrl,
  ...(gatewayKey ? { apiKey: gatewayKey } : {}),
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

export function getAgentModel(
  modelId: string = PRIMARY_AGENT_MODEL,
) {
  return gateway.languageModel(modelId);
}

export function getConfiguredAgentModels(): string[] {
  return [
    PRIMARY_AGENT_MODEL,
    ...FALLBACK_AGENT_MODELS,
  ];
}
