import 'dotenv/config';

const GATEWAY_URL = process.env.TRAVELER_GATEWAY_URL || 'http://127.0.0.1:7860/v1';
const MODEL = process.env.AGENT_PRIMARY_MODEL || 'minimax/minimax-m3:free';

async function verify() {
  console.log(`[VERIFY] Checking gateway connectivity at ${GATEWAY_URL}/models ...`);
  const modelsRes = await fetch(`${GATEWAY_URL}/models`);
  if (!modelsRes.ok) {
    const text = await modelsRes.text();
    throw new Error(`Gateway /v1/models failed (HTTP ${modelsRes.status}): ${text}`);
  }
  const modelsData = await modelsRes.json();
  console.log(`[VERIFY] Gateway /v1/models OK. Available models count: ${modelsData.data?.length || 'unknown'}`);

  console.log(`[VERIFY] Testing inference with model ${MODEL} ...`);
  const chatRes = await fetch(`${GATEWAY_URL}/chat/completions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: 'user', content: 'TRAVELER DEV VERCEL AGENT INFERENCE PASS' }
      ],
      max_tokens: 100,
    }),
  });

  const chatText = await chatRes.text();
  if (!chatRes.ok) {
    throw new Error(`Inference request failed (HTTP ${chatRes.status}): ${chatText}`);
  }

  let chatJson;
  try {
    chatJson = JSON.parse(chatText);
  } catch {
    throw new Error(`Invalid JSON response from gateway: ${chatText}`);
  }

  const content = chatJson.choices?.[0]?.message?.content;
  if (!content || typeof content !== 'string') {
    throw new Error(`Gateway returned empty or invalid content: ${chatText}`);
  }

  console.log(`[VERIFY] Inference SUCCESS! Model response: ${content.trim()}`);
  console.log('[VERIFY] Runtime verification passed completely.');
}

verify().catch((err) => {
  console.error('[VERIFY ERROR]', err);
  process.exit(1);
});
