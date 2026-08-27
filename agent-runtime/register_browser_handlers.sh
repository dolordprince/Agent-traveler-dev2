#!/usr/bin/env bash
set -e

cat << 'HANDLER_EOF' > src/tools/registerBrowserTools.ts
import { BrowserQAEngine } from './browserTools';

const browserQA = new BrowserQAEngine();

export async function handleBrowserToolCall(name: string, args: any): Promise<any> {
  switch (name) {
    case 'browser_start_server': {
      const { command, cwd, port } = args;
      const res = await browserQA.startDevServer(command, cwd, port);
      return JSON.stringify(res);
    }
    case 'browser_inspect_page': {
      const { url, artifactsDir } = args;
      await browserQA.initBrowser();
      const res = await browserQA.captureViewports(url, artifactsDir);
      return JSON.stringify(res);
    }
    case 'browser_stop_all': {
      await browserQA.stopAll();
      return JSON.stringify({ status: 'stopped' });
    }
    default:
      throw new Error(`Unknown browser tool: ${name}`);
  }
}
HANDLER_EOF

echo "==> Tool handler registered in src/tools/registerBrowserTools.ts"
