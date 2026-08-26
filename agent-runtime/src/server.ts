import 'dotenv/config';
import http from 'node:http';
import { createAgentUIStreamResponse } from 'ai';
import { createTravelerAgent } from './agent.js';

const port = Number(process.env.AGENT_RUNTIME_PORT || 8787);

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, {
        'content-type': 'application/json'
      });

      res.end(JSON.stringify({
        status: 'ok',
        service: 'traveler-dev-vercel-agent',
        provider: 'vercel-ai-gateway',
        primary_model:
          process.env.AGENT_PRIMARY_MODEL ||
          'anthropic/claude-sonnet-4.5'
      }));

      return;
    }

    if (
      req.method === 'POST' &&
      req.url === '/api/agent'
    ) {
      const chunks: Buffer[] = [];

      for await (const chunk of req) {
        chunks.push(Buffer.from(chunk));
      }

      const body = JSON.parse(
        Buffer.concat(chunks).toString('utf8')
      );

      const agent = createTravelerAgent();

      const response = await createAgentUIStreamResponse({
        agent,
        uiMessages: body.messages || []
      });

      res.writeHead(
        response.status || 200,
        Object.fromEntries(response.headers.entries())
      );

      const stream = response.body;

      if (!stream) {
        throw new Error('Agent returned no response body');
      }

      const reader = stream.getReader();

      while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        res.write(Buffer.from(value));
      }

      res.end();
      return;
    }

    res.writeHead(404, {
      'content-type': 'application/json'
    });

    res.end(JSON.stringify({
      detail: 'Not Found'
    }));
  } catch (error) {
    console.error(error);

    if (!res.headersSent) {
      res.writeHead(500, {
        'content-type': 'application/json'
      });
    }

    res.end(JSON.stringify({
      detail:
        error instanceof Error
          ? error.message
          : 'Agent runtime failure'
    }));
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(
    `TRAVELER DEV Vercel agent runtime listening on ${port}`
  );
});
