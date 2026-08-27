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
1. Use the provided tools for all real workspace operations.
2. Never claim a tool was executed unless the runtime returned its result.
3. Tool calls may be emitted using native tool calls, <tool_call> JSON, function XML, or the model's native <|tool_call_start|> syntax.
4. Continue executing until the requested work is actually completed.
5. For application development, inspect the workspace before modifying it.
6. For browser verification, start the real application, navigate with Playwright, interact with the rendered application, inspect diagnostics, repair failures, and retest.
7. Never substitute file inspection for browser verification.
8. Always verify file creation and run appropriate build/test commands before concluding.
9. Do not fabricate URLs, test results, deployment results, or successful tool execution.`;

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


function parseJsonObjects(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  let depth = 0;
  let startIndex = -1;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }

      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') {
      if (depth === 0) {
        startIndex = i;
      }

      depth += 1;
      continue;
    }

    if (char === '}') {
      depth -= 1;

      if (
        depth === 0 &&
        startIndex !== -1
      ) {
        const candidate = text.slice(
          startIndex,
          i + 1,
        );

        try {
          const parsed = JSON.parse(candidate) as {
            name?: unknown;
            arguments?: unknown;
          };

          if (
            typeof parsed.name === 'string' &&
            parsed.arguments !== null &&
            typeof parsed.arguments === 'object'
          ) {
            results.push({
              name: parsed.name,
              arguments:
                parsed.arguments as Record<
                  string,
                  unknown
                >,
            });
          }
        } catch {
          // Ignore unrelated JSON.
        }

        startIndex = -1;
      }
    }
  }

  return results;
}


function parseParameterValue(
  value: string,
): unknown {
  const trimmed = value.trim();

  if (
    trimmed.startsWith('"') &&
    trimmed.endsWith('"')
  ) {
    return trimmed.slice(1, -1);
  }

  if (
    trimmed.startsWith("'") &&
    trimmed.endsWith("'")
  ) {
    return trimmed.slice(1, -1);
  }

  if (trimmed === 'true') {
    return true;
  }

  if (trimmed === 'false') {
    return false;
  }

  if (trimmed === 'null') {
    return null;
  }

  if (
    /^-?\d+(\.\d+)?$/.test(trimmed)
  ) {
    return Number(trimmed);
  }

  return trimmed;
}


function parseFunctionSyntax(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const pattern =
    /<\|tool_call_start\|>\s*\[([A-Za-z_][A-Za-z0-9_]*)\(([\s\S]*?)\)\]\s*<\|tool_call_end\|>/g;

  for (const match of text.matchAll(pattern)) {
    const name = match[1];
    const rawArguments = match[2].trim();

    const argumentsObject:
      Record<string, unknown> = {};

    if (rawArguments.length > 0) {
      const argumentPattern =
        /([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:"((?:\\.|[^"])*)"|'((?:\\.|[^'])*)'|([^,]+))/g;

      for (
        const argument of
        rawArguments.matchAll(argumentPattern)
      ) {
        const raw =
          argument[2] ??
          argument[3] ??
          argument[4] ??
          '';

        argumentsObject[argument[1]] =
          parseParameterValue(raw);
      }
    }

    results.push({
      name,
      arguments: argumentsObject,
    });
  }

  return results;
}


function parseFunctionXml(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const functionPattern =
    /<function=([A-Za-z_][A-Za-z0-9_]*)>([\s\S]*?)<\/function>/g;

  for (
    const functionMatch of
    text.matchAll(functionPattern)
  ) {
    const name = functionMatch[1];
    const body = functionMatch[2];

    const argumentsObject:
      Record<string, unknown> = {};

    const parameterPattern =
      /<parameter=([A-Za-z_][A-Za-z0-9_]*)>\s*([\s\S]*?)\s*<\/parameter>/g;

    for (
      const parameterMatch of
      body.matchAll(parameterPattern)
    ) {
      argumentsObject[
        parameterMatch[1]
      ] = parseParameterValue(
        parameterMatch[2],
      );
    }

    results.push({
      name,
      arguments: argumentsObject,
    });
  }

  return results;
}


function extractToolCalls(
  content: string,
  nativeCalls?: Array<{
    id?: string;
    type?: string;
    function?: {
      name?: string;
      arguments?: string;
    };
  }>,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const calls: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  if (
    Array.isArray(nativeCalls) &&
    nativeCalls.length > 0
  ) {
    for (const call of nativeCalls) {
      if (!call.function?.name) {
        continue;
      }

      let parsedArgs:
        Record<string, unknown> = {};

      if (call.function.arguments) {
        try {
          parsedArgs = JSON.parse(
            call.function.arguments,
          ) as Record<string, unknown>;
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

  calls.push(
    ...parseFunctionXml(content),
  );

  calls.push(
    ...parseFunctionSyntax(content),
  );

  const taggedPattern =
    /<tool_call>\s*([\s\S]*?)\s*<\/tool_call>/g;

  for (
    const match of content.matchAll(taggedPattern)
  ) {
    calls.push(
      ...parseJsonObjects(match[1]),
    );
  }

  if (calls.length === 0) {
    calls.push(
      ...parseJsonObjects(content),
    );
  }

  const unique: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const seen = new Set<string>();

  for (const call of calls) {
    const key =
      `${call.name}:${JSON.stringify(call.arguments)}`;

    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    unique.push(call);
  }

  return unique;
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
