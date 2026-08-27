import 'dotenv/config';

import {
  createServer,
  type IncomingMessage,
  type ServerResponse,
} from 'node:http';

import {
  getAgentRuntimeStatus,
  runTravelerAgent,
} from './agent.js';

const PORT = Number(
  process.env.PORT || 8090,
);

function sendJson(
  response: ServerResponse,
  status: number,
  payload: unknown,
): void {
  response.statusCode = status;
  response.setHeader(
    'content-type',
    'application/json; charset=utf-8',
  );

  response.end(
    JSON.stringify(payload),
  );
}

async function readBody(
  request: IncomingMessage,
): Promise<string> {
  const chunks: Buffer[] = [];

  for await (const chunk of request) {
    chunks.push(
      Buffer.isBuffer(chunk)
        ? chunk
        : Buffer.from(chunk),
    );
  }

  return Buffer.concat(chunks).toString('utf8');
}

const server = createServer(
  async (request, response) => {
    try {
      const method =
        request.method || 'GET';

      const url = new URL(
        request.url || '/',
        `http://${request.headers.host || '127.0.0.1'}`,
      );

      if (
        method === 'GET' &&
        (url.pathname === '/health' ||
          url.pathname === '/api/health')
      ) {
        sendJson(response, 200, {
          status: 'ok',
          service: 'traveler-dev-agent-runtime',
          ...getAgentRuntimeStatus(),
        });

        return;
      }

      if (
        method === 'GET' &&
        url.pathname === '/api/config'
      ) {
        sendJson(response, 200, {
          status: 'ok',
          ...getAgentRuntimeStatus(),
        });

        return;
      }

      if (
        method === 'POST' &&
        (
          url.pathname === '/api/agent/run' ||
          url.pathname === '/agent/run'
        )
      ) {
        const rawBody =
          await readBody(request);

        const body = JSON.parse(
          rawBody || '{}',
        ) as {
          prompt?: unknown;
          message?: unknown;
        };

        const prompt =
          typeof body.prompt === 'string'
            ? body.prompt
            : typeof body.message === 'string'
              ? body.message
              : '';

        if (!prompt.trim()) {
          sendJson(response, 400, {
            detail:
              'prompt or message is required',
          });

          return;
        }

        const result =
          await runTravelerAgent(
            prompt,
          );

        sendJson(response, 200, {
          status: 'completed',
          ...result,
        });

        return;
      }

      sendJson(response, 404, {
        detail: 'Not found',
      });
    } catch (error) {
      console.error(error);

      sendJson(response, 500, {
        detail:
          error instanceof Error
            ? error.message
            : String(error),
      });
    }
  },
);

server.listen(
  PORT,
  '127.0.0.1',
  () => {
    console.log(
      `TRAVELER DEV agent runtime listening on http://127.0.0.1:${PORT}`,
    );
  },
);
