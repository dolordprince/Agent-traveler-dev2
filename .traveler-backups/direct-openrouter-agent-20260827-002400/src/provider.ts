import 'dotenv/config';

const GATEWAY_BASE_URL =
  process.env.TRAVELER_GATEWAY_URL ||
  process.env.OPENROUTER_BASE_URL ||
  'http://127.0.0.1:7860/v1';

const PRIMARY_MODEL =
  process.env.AGENT_PRIMARY_MODEL ||
  process.env.OPENROUTER_MODEL ||
  'anthropic/claude-sonnet-4';

const FALLBACK_MODELS = (
  process.env.AGENT_FALLBACK_MODELS ||
  process.env.OPENROUTER_FALLBACK_MODEL ||
  'openrouter/free'
)
  .split(',')
  .map((value: string) => value.trim())
  .filter(Boolean);

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface ChatResponse {
  id?: string;
  model?: string;
  content: string;
  raw: unknown;
}

function endpoint(path: string): string {
  return `${GATEWAY_BASE_URL.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`;
}

async function requestModel(
  model: string,
  messages: ChatMessage[],
): Promise<ChatResponse> {
  const response = await fetch(endpoint('/chat/completions'), {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages,
      max_tokens: 4096,
    }),
  });

  const rawText = await response.text();

  let raw: unknown;
  try {
    raw = JSON.parse(rawText);
  } catch {
    raw = rawText;
  }

  if (!response.ok) {
    throw new Error(
      `Gateway inference failed: HTTP ${response.status}: ${rawText}`,
    );
  }

  const data = raw as {
    id?: string;
    model?: string;
    choices?: Array<{
      message?: {
        content?: string;
      };
    }>;
  };

  const content = data.choices?.[0]?.message?.content;

  if (typeof content !== 'string') {
    throw new Error(
      `Gateway returned an invalid chat completion response: ${rawText}`,
    );
  }

  return {
    id: data.id,
    model: data.model || model,
    content,
    raw,
  };
}

export function getConfiguredModels(): string[] {
  return [PRIMARY_MODEL, ...FALLBACK_MODELS.filter((m) => m !== PRIMARY_MODEL)];
}

export async function generateAgentText(
  messages: ChatMessage[],
): Promise<ChatResponse> {
  const models = getConfiguredModels();

  let lastError: unknown;

  for (const model of models) {
    try {
      return await requestModel(model, messages);
    } catch (error) {
      lastError = error;
    }
  }

  throw new Error(
    `All configured coding-agent models failed. Last error: ${
      lastError instanceof Error ? lastError.message : String(lastError)
    }`,
  );
}
