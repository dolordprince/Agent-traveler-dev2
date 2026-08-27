import { generateAgentText, ChatMessage } from './provider.js';
import { toolsSchema, executeToolCall } from './tools.js';

export interface AgentRequest {
  messages: ChatMessage[];
  maxSteps?: number;
}

export interface AgentResult {
  content: string;
  model?: string;
  id?: string;
  steps: number;
  toolCalls: number;
}

export function getAgentRuntimeStatus() {
  return {
    status: 'online',
    runtime: 'native-typescript',
    workspaceRoot: process.env.TRAVELER_WORKSPACE_ROOT || '/root/Agent-traveler-dev2/workspace',
    knowledgeRoot: process.env.TRAVELER_KNOWLEDGE_ROOT || '/root/Agent-traveler-dev2/knowledge',
  };
}

export async function runTravelerAgent(request: AgentRequest): Promise<AgentResult> {
  const maxSteps = request.maxSteps || 30;
  const messages: ChatMessage[] = [
    {
      role: 'system',
      content: `You are TRAVELER DEV, an elite autonomous coding agent operating in a real workspace with actual files, dependencies, tests, and builds. Use tools iteratively to inspect the workspace, implement solutions, run tests, and provide a clear final summary.`,
    },
    ...request.messages,
  ];

  let steps = 0;
  let totalToolCalls = 0;
  let lastModel: string | undefined;
  let lastId: string | undefined;

  while (steps < maxSteps) {
    steps++;
    const response = await generateAgentText(messages, toolsSchema);
    lastModel = response.model;
    lastId = response.id;

    if (response.toolCalls && response.toolCalls.length > 0) {
      messages.push({
        role: 'assistant',
        content: response.content,
        tool_calls: response.toolCalls,
      });

      for (const call of response.toolCalls) {
        totalToolCalls++;
        let toolResult: any;
        try {
          const parsedArgs = JSON.parse(call.function.arguments || '{}');
          toolResult = await executeToolCall(call.function.name, parsedArgs);
        } catch (err: any) {
          toolResult = { error: err.message || String(err) };
        }

        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          name: call.function.name,
          content: typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult),
        });
      }
      continue;
    }

    return {
      content: response.content || 'Agent completed task successfully.',
      model: lastModel,
      id: lastId,
      steps,
      toolCalls: totalToolCalls,
    };
  }

  return {
    content: `Agent reached maximum steps limit (${maxSteps}) without final completion.`,
    model: lastModel,
    id: lastId,
    steps,
    toolCalls: totalToolCalls,
  };
}
