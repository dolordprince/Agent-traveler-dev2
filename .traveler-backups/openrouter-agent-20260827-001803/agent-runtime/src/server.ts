import 'dotenv/config';
import http from 'node:http';

import {
  createAgentUIStreamResponse,
} from 'ai';

import {
  createTravelerAgent,
} from './agent.js';

const port = Number(
  process.env.AGENT_RUNTIME_PORT || 8787,
);

const MAX_BODY = 2 * 1024 * 1024;

async function readBody(
  req: http.IncomingMessage,
): Promise<any> {
  const chunks: Buffer[] = [];
  let total = 0;

  for await (const chunk of req) {
    const buffer = Buffer.from(chunk);

    total += buffer.length;

    if (total > MAX_BODY) {
      throw new Error(
        'Request body exceeds 2 MB.',
      );
    }

    chunks.push(buffer);
  }

  const raw = Buffer.concat(chunks)
    .toString('utf8');

  return raw ? JSON.parse(raw) : {};
}

function json(
  res: http.ServerResponse,
  status: number,
  payload: unknown,
) {
  const body = JSON.stringify(payload);

  res.writeHead(status, {
    'content-type':
      'application/json; charset=utf-8',
    'content-length':
      Buffer.byteLength(body),
  });

  res.end(body);
}

const server = http.createServer(
  async (req, res) => {
    try {
      if (
        req.method === 'GET' &&
        req.url === '/health'
      ) {
        return json(res, 200, {
          status: 'ok',
          service:
            'traveler-dev-coding-agent',
          runtime: 'vercel-ai-sdk',
          model:
            process.env.AGENT_PRIMARY_MODEL ||
            'anthropic/claude-sonnet-4',
          deployment_target: 'surge',
          gateway:
            process.env.TRAVELER_GATEWAY_URL ||
            'https://agent-traveler-dev2.onrender.com',
        });
      }

      if (
        req.method === 'POST' &&
        req.url === '/api/agent'
      ) {
        const body = await readBody(req);

        const agent =
          createTravelerAgent();

        const response =
          await createAgentUIStreamResponse({
            agent,
            uiMessages:
              body.messages || [],
          });

        res.writeHead(
          response.status || 200,
          Object.fromEntries(
            response.headers.entries(),
          ),
        );

        if (!response.body) {
          throw new Error(
            'Agent returned no response body.',
          );
        }

        const reader =
          response.body.getReader();

        while (true) {
          const { done, value } =
            await reader.read();

          if (done) {
            break;
          }

          res.write(
            Buffer.from(value),
          );
        }

        res.end();
        return;
      }

      return json(res, 404, {
        error: 'Not Found',
      });
    } catch (error) {
      console.error(
        '[TRAVELER DEV AGENT ERROR]',
        error,
      );

      if (!res.headersSent) {
        return json(res, 500, {
          error:
            error instanceof Error
              ? error.message
              : String(error),
        });
      }

      res.end();
    }
  },
);

server.listen(
  port,
  '0.0.0.0',
  () => {
    console.log(
      `TRAVELER DEV coding agent listening on ${port}`,
    );
  },
);
