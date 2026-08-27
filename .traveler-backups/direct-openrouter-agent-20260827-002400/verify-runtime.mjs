import 'dotenv/config';

const gateway =
  process.env.TRAVELER_GATEWAY_URL ||
  'http://127.0.0.1:7860/v1';

const model =
  process.env.AGENT_PRIMARY_MODEL ||
  process.env.OPENROUTER_MODEL ||
  'anthropic/claude-sonnet-4';

console.log('============================================================');
console.log('TRAVELER DEV — DIRECT OPENROUTER CODING AGENT VERIFICATION');
console.log('============================================================');
console.log(`Gateway: ${gateway}`);
console.log(`Model:   ${model}`);
console.log('Auth:    none between local agent and gateway');
console.log();

const health = await fetch(
  `${gateway.replace(/\/+$/, '').replace(/\/v1$/, '')}/health`,
);

if (!health.ok) {
  throw new Error(`Gateway health failed: HTTP ${health.status}`);
}

console.log('[PASS] Gateway health endpoint reachable.');

const response = await fetch(
  `${gateway.replace(/\/+$/, '')}/chat/completions`,
  {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content:
            'You are performing a production TRAVELER DEV coding-agent connectivity test.',
        },
        {
          role: 'user',
          content:
            'Return exactly: TRAVELER DEV CODING AGENT INFERENCE PASS',
        },
      ],
      max_tokens: 64,
    }),
  },
);

const body = await response.text();

if (!response.ok) {
  throw new Error(
    `Gateway inference failed: HTTP ${response.status}: ${body}`,
  );
}

let data;

try {
  data = JSON.parse(body);
} catch {
  throw new Error(`Gateway returned non-JSON response: ${body}`);
}

const content = data?.choices?.[0]?.message?.content;

if (typeof content !== 'string') {
  throw new Error(`Invalid OpenAI-compatible response: ${body}`);
}

console.log('[PASS] OpenAI-compatible inference endpoint responded.');
console.log(`Response: ${content}`);

if (!content.includes('TRAVELER DEV CODING AGENT INFERENCE PASS')) {
  throw new Error('Inference response did not contain the expected verification text.');
}

console.log();
console.log('============================================================');
console.log('TRAVELER DEV — CODING AGENT VERIFICATION: PASS');
console.log('============================================================');
