import * as http from 'http';
import 'dotenv/config';
import { runTravelerAgent, getAgentRuntimeStatus } from './agent.js';
import { getConfiguredModels } from './provider.js';

const PORT = parseInt(process.env.PORT || '3000', 10);

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    if (req.method === 'GET' && (pathname === '/health' || pathname === '/api/health')) {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', service: 'traveler-dev-agent-runtime' }));
      return;
    }

    if (req.method === 'GET' && pathname === '/api/config') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(
        JSON.stringify({
          models: getConfiguredModels(),
          workspaceRoot: process.env.TRAVELER_WORKSPACE_ROOT || '/root/Agent-traveler-dev2/workspace',
          knowledgeRoot: process.env.TRAVELER_KNOWLEDGE_ROOT || '/root/Agent-traveler-dev2/knowledge',
        }),
      );
      return;
    }

    if (req.method === 'GET' && pathname === '/api/runtime/status') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(getAgentRuntimeStatus()));
      return;
    }

    if (req.method === 'POST' && pathname === '/api/agent/run') {
      let bodyStr = '';
      for await (const chunk of req) {
        bodyStr += chunk;
      }

      let body: any;
      try {
        body = JSON.parse(bodyStr || '{}');
      } catch {
        res.writeHead(400, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON body' }));
        return;
      }

      const prompt = body.prompt || body.message;
      let messages = body.messages;
      const maxSteps = body.maxSteps;

      if (!messages && prompt) {
        messages = [{ role: 'user', content: prompt }];
      }

      if (!messages || !Array.isArray(messages) || messages.length === 0) {
        res.writeHead(400, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: 'Missing prompt or messages array in request body' }));
        return;
      }

      const result = await runTravelerAgent({ messages, maxSteps });
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(result));
      return;
    }

    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not Found' }));
  } catch (err: any) {
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: err.message || String(err) }));
  }
});

server.listen(PORT, () => {
  console.log(`Traveler Dev Agent Runtime server listening on port ${PORT}`);
});
