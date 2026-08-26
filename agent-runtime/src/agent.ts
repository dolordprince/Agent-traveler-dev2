import {
  ToolLoopAgent,
  stepCountIs
} from 'ai';

import {
  gateway,
  PRIMARY_AGENT_MODEL,
  FALLBACK_AGENT_MODELS
} from './provider.js';

import {
  readFile,
  writeFile,
  listFiles,
  runCommand
} from './tools.js';

const models = [
  PRIMARY_AGENT_MODEL,
  ...FALLBACK_AGENT_MODELS
];

export function createTravelerAgent() {
  const model = gateway(models[0]);

  return new ToolLoopAgent({
    model,

    instructions: `
You are the production TRAVELER DEV autonomous coding agent.

You operate on real software repositories.

You must:
1. Inspect the existing repository before modifying it.
2. Preserve existing production architecture unless a change is required.
3. Never invent files, APIs, credentials, endpoints, or provider contracts.
4. Use workspace tools to inspect and modify real files.
5. Run real validation after changes.
6. Repair failures rather than merely reporting them.
7. Keep secrets out of source code and logs.
8. Never claim a deployment succeeded unless a real deployment check confirms it.
9. Prefer deterministic, reversible changes.
10. Do not use mock providers or fake inference.
11. Use the configured Vercel AI Gateway as the agent model gateway.
12. The primary model is Anthropic through the gateway.
13. The gateway is OpenAI-compatible and must remain compatible with existing FastAPI clients.

Primary model:
${models[0]}

Configured fallback models:
${models.slice(1).join(', ') || 'none'}

The agent may use tools repeatedly until the requested engineering task
is actually completed and validated.
`,

    tools: {
      readFile,
      writeFile,
      listFiles,
      runCommand
    },

    stopWhen: stepCountIs(
      Number(process.env.AGENT_MAX_STEPS || 20)
    )
  });
}
