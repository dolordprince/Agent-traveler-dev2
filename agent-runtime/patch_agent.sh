#!/usr/bin/env bash
set -e

cat << 'TS_EOF' > src/agent.ts
import {
  generateAgentText,
  getConfiguredModels,
  type ChatMessage,
} from './provider.js';
import {
  readFile,
  writeFile,
  listFiles,
  runCommand,
  searchKnowledge,
  readKnowledge,
  listKnowledge,
  executeTool,
  TOOL_DEFINITIONS,
  WORKSPACE_ROOT,
  KNOWLEDGE_ROOT,
} from './tools.js';

export {
  readFile,
  writeFile,
  listFiles,
  runCommand,
  searchKnowledge,
  readKnowledge,
  listKnowledge,
};

const models = getConfiguredModels();

function toolCatalogText(): string {
  return TOOL_DEFINITIONS.map(
    (def) =>
      `- Function: ${def.function.name}\n  Description: ${def.function.description}\n  Parameters JSON Schema: ${JSON.stringify(def.function.parameters)}`,
  ).join('\n\n');
}

const SYSTEM_INSTRUCTIONS = `You are the TRAVELER DEV autonomous production coding agent.
Your job is to turn a user request into a COMPLETE working application, website, integration, or software feature.
You operate against a REAL workspace and a REAL Markdown technical knowledge base.

AVAILABLE TOOLS:
${toolCatalogText()}

TOOL CALLING INSTRUCTIONS:
To use a tool, emit each tool call strictly in its own block:

<tool_call>
{
  "name": "tool_name",
  "arguments": {
    "param_name": "param_value"
  }
}
</tool_call>

RULES:
1. Every tool call MUST be enclosed in <tool_call> tags and contain ONE valid JSON object.
2. If you need to invoke multiple tools, you can use multiple separate <tool_call>...</tool_call> tags.
3. Always verify file creation and run test/build commands before concluding.`;

export interface AgentRequest {
  prompt?: string;
  messages?: ChatMessage[];
  maxSteps?: number;
}

export interface AgentResult {
  content: string;
  model?: string;
  id?: string;
  steps: number;
  toolCalls: number;
}

export function getAgentRuntimeStatus(): {
  available: boolean;
  configuredModels: string[];
  workspaceRoot: string;
  knowledgeRoot: string;
} {
  return {
    available: true,
    configuredModels: models,
    workspaceRoot: WORKSPACE_ROOT,
    knowledgeRoot: KNOWLEDGE_ROOT,
  };
}

// Bulletproof Brace-Counting JSON Extractor
function parseJsonObjects(text: string): Array<{ name: string; arguments: Record<string, unknown> }> {
  const results: Array<{ name: string; arguments: Record<string, unknown> }> = [];
  let depth = 0;
  let startIndex = -1;

  for (let i = 0; i < text.length; i++) {
    if (text[i] === '{') {
      if (depth === 0) {
        startIndex = i;
      }
      depth++;
    } else if (text[i] === '}') {
      depth--;
      if (depth === 0 && startIndex !== -1) {
        const jsonStr = text.substring(startIndex, i + 1);
        try {
          const parsed = JSON.parse(jsonStr) as { name?: unknown; arguments?: unknown };
          if (
            typeof parsed.name === 'string' &&
            parsed.arguments !== null &&
            typeof parsed.arguments === 'object'
          ) {
            results.push({
              name: parsed.name,
              arguments: parsed.arguments as Record<string, unknown>,
            });
          }
        } catch (e) {
          // Ignore invalid JSON chunks
        }
        startIndex = -1;
      }
    }
  }

  return results;
}

function extractToolCalls(
  content: string,
  nativeCalls?: Array<{
    id?: string;
    type?: string;
    function?: { name?: string; arguments?: string };
  }>,
): Array<{ name: string; arguments: Record<string, unknown> }> {
  const calls: Array<{ name: string; arguments: Record<string, unknown> }> = [];

  // 1. Process native tool_calls
  if (Array.isArray(nativeCalls) && nativeCalls.length > 0) {
    for (const call of nativeCalls) {
      if (call.function?.name) {
        let parsedArgs: Record<string, unknown> = {};
        if (call.function.arguments) {
          try {
            parsedArgs = JSON.parse(call.function.arguments) as Record<string, unknown>;
          } catch {
            parsedArgs = {};
          }
        }
        calls.push({
          name: call.function.name,
          arguments: parsedArgs,
        });
      }
    }
  }

  // 2. Extract tools from text using robust brace-counting (even loose JSON blocks)
  const toolPattern = /<tool_call>([\s\S]*?)<\/tool_call>/g;
  const toolMatches = Array.from(content.matchAll(toolPattern));
  
  if (toolMatches.length > 0) {
    for (const match of toolMatches) {
      calls.push(...parseJsonObjects(match[1]));
    }
  } else {
    // 3. Fallback: If model forgot <tool_call> tags entirely, try parsing loose JSON objects
    calls.push(...parseJsonObjects(content));
  }

  return calls;
}

export async function runTravelerAgent(
  request: string | AgentRequest,
): Promise<AgentResult> {
  const normalizedRequest: AgentRequest =
    typeof request === 'string' ? { prompt: request } : request;

  const maxSteps = Math.max(
    1,
    Math.min(
      normalizedRequest.maxSteps ??
        Number(process.env.AGENT_MAX_STEPS || 50),
      100,
    ),
  );

  const initialMessages: ChatMessage[] = [];
  if (normalizedRequest.messages && normalizedRequest.messages.length > 0) {
    initialMessages.push(...normalizedRequest.messages);
  } else if (normalizedRequest.prompt) {
    initialMessages.push({
      role: 'user',
      content: normalizedRequest.prompt,
    });
  }

  const messages: ChatMessage[] = [
    {
      role: 'system',
      content: SYSTEM_INSTRUCTIONS,
    },
    ...initialMessages,
  ];

  let finalContent = '';
  let model: string | undefined;
  let id: string | undefined;
  let steps = 0;
  let toolCalls = 0;

  while (steps < maxSteps) {
    steps += 1;

    const response = await generateAgentText(messages, TOOL_DEFINITIONS);
    finalContent = response.content;
    model = response.model;
    id = response.id;

    const calls = extractToolCalls(response.content, response.toolCalls);

    if (calls.length === 0) {
      break;
    }

    toolCalls += calls.length;

    messages.push({
      role: 'assistant',
      content: response.content || 'Executing tools...',
    });

    for (const call of calls) {
      try {
        const result = await executeTool(call.name, call.arguments);
        messages.push({
          role: 'user',
          content: `TOOL RESULT (${call.name}):\n${JSON.stringify(result, null, 2)}`,
        });
      } catch (error) {
        messages.push({
          role: 'user',
          content: `TOOL ERROR (${call.name}):\n${
            error instanceof Error ? error.message : String(error)
          }`,
        });
      }
    }
  }

  return {
    content: finalContent,
    model,
    id,
    steps,
    toolCalls,
  };
}

export function createTravelerAgent() {
  return {
    run: runTravelerAgent,
    models,
    tools: TOOL_DEFINITIONS,
  };
}
TS_EOF

echo "==> Rebuilding agent runtime..."
npm run build

echo "==> Restarting background server..."
pkill -9 -f 'node.*dist/server.js' || true
sleep 1
node dist/server.js > runtime.log 2>&1 &
sleep 2

echo "==> Executing Production Acceptance Test..."
./test_production_app.sh
