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

export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string;
  };
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | null;
  tool_calls?: ToolCall[];
  tool_call_id?: string;
  name?: string;
}

export interface ChatResponse {
  id?: string;
  model?: string;
  content: string | null;
  toolCalls?: ToolCall[];
  raw: unknown;
}

function endpoint(path: string): string {
  return `${GATEWAY_BASE_URL.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`;
}

async function requestModel(
  model: string,
  messages: ChatMessage[],
  tools?: unknown[],
): Promise<ChatResponse> {
  const body: Record<string, unknown> = {
    model,
    messages,
    max_tokens: 4096,
  };
  if (tools && tools.length > 0) {
    body.tools = tools;
  }

  const response = await fetch(endpoint('/chat/completions'), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

  const rawText = await response.text();
  let raw: unknown;
  try {
    raw = JSON.parse(rawText);
  } catch {
    raw = rawText;
  }

  if (!response.ok) {
    throw new Error(`Gateway inference failed: HTTP ${response.status}: ${rawText}`);
  }

  const data = raw as {
    id?: string;
    model?: string;
    choices?: Array<{
      message?: {
        content?: string | null;
        tool_calls?: ToolCall[];
      };
    }>;
  };

  const msg = data.choices?.[0]?.message;
  const content = msg?.content ?? null;
  const toolCalls = msg?.tool_calls;

  if (content === null && (!toolCalls || toolCalls.length === 0)) {
    throw new Error(`Gateway returned an invalid chat completion response: ${rawText}`);
  }

  return {
    id: data.id,
    model: data.model || model,
    content,
    toolCalls,
    raw,
  };
}

export function getConfiguredModels(): string[] {
  return [PRIMARY_MODEL, ...FALLBACK_MODELS.filter((m) => m !== PRIMARY_MODEL)];
}

export async function generateAgentText(
  messages: ChatMessage[],
  tools?: unknown[],
): Promise<ChatResponse> {
  const models = getConfiguredModels();
  let lastError: unknown;

  for (const model of models) {
    try {
      return await requestModel(model, messages, tools);
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
