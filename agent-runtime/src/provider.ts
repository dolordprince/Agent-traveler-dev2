import 'dotenv/config';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string;
  };
}

export interface ChatResponse {
  id?: string;
  model?: string;
  content: string;
  toolCalls: ToolCall[];
  raw: unknown;
}

const GATEWAY_URL = (
  process.env.TRAVELER_GATEWAY_URL ||
  process.env.OPENROUTER_BASE_URL ||
  'http://127.0.0.1:7860/v1'
).replace(/\/+$/, '');

const PRIMARY_MODEL =
  process.env.AGENT_PRIMARY_MODEL ||
  process.env.OPENROUTER_MODEL ||
  'minimax/minimax-m3:free';

const FALLBACK_MODELS = (
  process.env.AGENT_FALLBACK_MODELS ||
  process.env.OPENROUTER_FALLBACK_MODEL ||
  'openrouter/free'
)
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

export function getConfiguredModels(): string[] {
  return [
    PRIMARY_MODEL,
    ...FALLBACK_MODELS.filter((model) => model !== PRIMARY_MODEL),
  ];
}

export async function generateAgentText(
  messages: ChatMessage[],
  tools?: unknown[],
): Promise<ChatResponse> {
  const models = getConfiguredModels();
  let lastError: unknown;

  for (const model of models) {
    try {
      const response = await fetch(`${GATEWAY_URL}/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages,
          tools,
          tool_choice: tools?.length ? 'auto' : undefined,
          max_tokens: Number(process.env.AGENT_MAX_TOKENS || 8192),
          temperature: 0.1,
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
          `Gateway inference failed for ${model}: HTTP ${response.status}: ${rawText}`,
        );
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

      const message = data.choices?.[0]?.message;

      if (!message) {
        throw new Error(
          `Gateway returned no assistant message for ${model}.`,
        );
      }

      return {
        id: data.id,
        model: data.model || model,
        content:
          typeof message.content === 'string'
            ? message.content
            : '',
        toolCalls: Array.isArray(message.tool_calls)
          ? message.tool_calls
          : [],
        raw,
      };
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
