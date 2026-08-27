import 'dotenv/config';

import { generateText } from 'ai';
import {
  gateway,
  PRIMARY_AGENT_MODEL
} from '../src/provider.js';

const result = await generateText({
  model: gateway(PRIMARY_AGENT_MODEL),
  prompt:
    'Respond with exactly: TRAVELER DEV VERCEL AI SDK TEST PASS'
});

console.log('MODEL:', PRIMARY_AGENT_MODEL);
console.log('RESPONSE:', result.text);
console.log('FINISH_REASON:', await result.finishReason);
console.log('USAGE:', await result.usage);
