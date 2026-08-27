import 'dotenv/config';
import http from 'node:http';
import { generateAgentText, getConfiguredModels } from './provider.js';

const port = Number(process.env.AGENT_RUNTIME_PORT || 8787);

const systemPrompt =
  process.env.AGENT_SYSTEM_PROMPT ||
  [
    'You are the TRAVELER DEV production coding agent.',
    'You are an autonomous software engineering agent.',
    'Inspect the workspace before changing it.',
    'Use the available workspace and knowledge context supplied by the caller.',
    'Produce production-quality implementation decisions.',
    'Never claim a build, test, deployment, or file modification occurred unless it actually occurred.',
  ].join(' ');

function send(
  res: http.ServerResponse,
  status: number,
  payload: unknown,
): void {
  const body = JSON.stringify(payload);

  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });

  res.end(body);
}

async function readBody(req: http.IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];

  for await (const chunk of req) {
    chunks.push(Buffer.from(chunk));
  }

  return Buffer.concat(chunks).toString('utf8');
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'GET' && url.pathname === '/health') {
      send(res, 200, {
        status: 'ok',
        service: 'traveler-dev-agent-runtime',
        authentication: 'none',
        gateway: process.env.TRAVELER_GATEWAY_URL ||
          'http://127.0.0.1:7860/v1',
        models: getConfiguredModels(),
      });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/agent/run') {
      const raw = await readBody(req);

      let body: {
        prompt?: string;
        messages?: Array<{
          role: 'system' | 'user' | 'assistant';
          content: string;
        }>;
      };

      try {
        body = JSON.parse(raw);
      } catch {
        send(res, 400, { error: 'Request body must be valid JSON.' });
        return;
      }

      const messages = body.messages?.length
        ? body.messages
        : [
            { role: 'system' as const, content: systemPrompt },
            {
              role: 'user' as const,
              content: body.prompt || '',
            },
          ];

      if (!messages.some((message) => message.role === 'system')) {
        messages.unshift({
          role: 'system',
          content: systemPrompt,
        });
      }

      const result = await generateAgentText(messages);

      send(res, 200, {
        status: 'ok',
        model: result.model,
        content: result.content,
        response: result.raw,
      });
      return;
    }

    send(res, 404, {
      error: 'Not found',
      endpoints: [
        'GET /health',
        'POST /agent/run',
      ],
    });
  } catch (error) {
    send(res, 500, {
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`TRAVELER DEV agent runtime listening on 127.0.0.1:${port}`);
});
