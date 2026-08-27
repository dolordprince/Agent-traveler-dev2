import 'dotenv/config';

const base =
  process.env.TRAVELER_AGENT_URL ||
  'http://127.0.0.1:8090';

const apiKey =
  process.env.OPENROUTER_API_KEY?.trim();

const model =
  process.env.AGENT_PRIMARY_MODEL ||
  process.env.OPENROUTER_MODEL ||
  'anthropic/claude-sonnet-4';

console.log('============================================================');
console.log('TRAVELER DEV — DIRECT OPENROUTER CODING AGENT VERIFICATION');
console.log('============================================================');
console.log(`Runtime: ${base}`);
console.log(`Provider: OpenRouter`);
console.log(`Model: ${model}`);
console.log('Gateway authentication: not used');
console.log();

if (!apiKey) {
  throw new Error(
    'OPENROUTER_API_KEY is required for direct OpenRouter inference.',
  );
}

const healthResponse =
  await fetch(`${base}/health`);

if (!healthResponse.ok) {
  throw new Error(
    `Agent runtime health failed: HTTP ${healthResponse.status}`,
  );
}

const health =
  await healthResponse.json();

console.log('[PASS] Agent runtime health.');
console.log(JSON.stringify(health));
console.log();

const response =
  await fetch(`${base}/api/agent/run`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      prompt:
        'Return exactly: TRAVELER DEV DIRECT OPENROUTER AGENT PASS',
    }),
  });

const raw = await response.text();

if (!response.ok) {
  throw new Error(
    `Agent inference failed: HTTP ${response.status}: ${raw}`,
  );
}

const result = JSON.parse(raw);

if (
  typeof result.content !== 'string' ||
  !result.content.includes(
    'TRAVELER DEV DIRECT OPENROUTER AGENT PASS',
  )
) {
  throw new Error(
    `Unexpected agent response: ${raw}`,
  );
}

console.log('[PASS] Direct OpenRouter agent inference.');
console.log(`Model: ${result.model}`);
console.log(`Steps: ${result.steps}`);
console.log(`Tool calls: ${result.toolCalls}`);
console.log(`Response: ${result.content}`);
console.log();
console.log('============================================================');
console.log('TRAVELER DEV — DIRECT OPENROUTER AGENT: PASS');
console.log('============================================================');
