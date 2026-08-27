import {
  generateAgentText,
  getConfiguredModels,
  type ChatMessage,
} from './provider.js';

import {
  executeTool,
  TOOL_DEFINITIONS as unknown as unknown[],
} from './tools.js';

const MAX_STEPS = Number(
  process.env.AGENT_MAX_STEPS || 50,
);

const SYSTEM_PROMPT = `
You are the TRAVELER DEV autonomous production coding agent.

You turn user requests into complete working software.

You operate on a REAL workspace and a REAL Markdown technical
knowledge base.

MANDATORY WORKFLOW:

1. Inspect the workspace.
2. Inspect available Markdown knowledge.
3. Search relevant technical documentation.
4. Read relevant documents.
5. Design the implementation from the actual project state.
6. Modify real files.
7. Install required dependencies.
8. Run real tests, type checks, linting, and builds where applicable.
9. Inspect actual failures.
10. Repair actual failures.
11. Re-run validation.
12. Continue until the implementation is actually working.

PRODUCTION RULES:

- Work only on real files.
- Never fabricate tool results.
- Never fabricate tests.
- Never fabricate build success.
- Never fabricate deployment success.
- Never use mock providers.
- Never create fake APIs.
- Never invent credentials.
- Never expose credentials.
- Never hard-code secrets.
- Preserve existing architecture.
- Do not delete unrelated production code.
- Use the Markdown knowledge base as project knowledge.
- Prefer existing dependencies.
- Add dependencies only when necessary.
- Validate the final implementation.

DEPLOYMENT:

Generated web projects use the TRAVELER DEV production deployment
pipeline rather than treating Vercel as the generated-project
deployment provider.

Never claim deployment succeeded until the real deployment operation
has completed and the live result has been checked.
`.trim();

export interface AgentRunResult {
  content: string;
  model?: string;
  steps: number;
  toolCalls: number;
}

export async function runTravelerAgent(
  userPrompt: string,
): Promise<AgentRunResult> {
  const messages: ChatMessage[] = [
    {
      role: 'system',
      content: SYSTEM_PROMPT,
    },
    {
      role: 'user',
      content: userPrompt,
    },
  ];

  let lastModel: string | undefined;
  let toolCalls = 0;

  for (
    let step = 1;
    step <= MAX_STEPS;
    step += 1
  ) {
    const response = await generateAgentText(
      messages,
      TOOL_DEFINITIONS as unknown as unknown[],
    );

    lastModel = response.model;

    messages.push({
      role: 'assistant',
      content: response.content,
    });

    if (
      response.toolCalls.length === 0
    ) {
      return {
        content: response.content,
        model: lastModel,
        steps: step,
        toolCalls,
      };
    }

    for (const toolCall of response.toolCalls) {
      toolCalls += 1;

      let input: unknown = {};

      try {
        input = JSON.parse(
          toolCall.function.arguments || '{}',
        );
      } catch {
        input = {};
      }

      try {
        const result = await executeTool(
          toolCall.function.name,
          input,
        );

        messages.push({
          role: 'tool',
          content: JSON.stringify({
            tool_call_id: toolCall.id,
            name: toolCall.function.name,
            result,
          }),
        });
      } catch (error) {
        messages.push({
          role: 'tool',
          content: JSON.stringify({
            tool_call_id: toolCall.id,
            name: toolCall.function.name,
            error:
              error instanceof Error
                ? error.message
                : String(error),
          }),
        });
      }
    }
  }

  throw new Error(
    `Coding agent exceeded AGENT_MAX_STEPS=${MAX_STEPS} without completing.`,
  );
}

export function getAgentRuntimeStatus() {
  return {
    runtime: 'traveler-dev-direct-openrouter',
    provider: 'openrouter',
    authentication:
      'OpenRouter API authentication required',
    gateway_authentication: 'not used',
    models: getConfiguredModels(),
    max_steps: MAX_STEPS,
  };
}
