#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "============================================================"
echo "TRAVELER DEV — PRODUCTION BROWSER AGENT INTEGRATION REPAIR"
echo "============================================================"

test -f src/tools.ts
test -f src/agent.ts
test -f browser_engine.py
test -f app_supervisor.py

cp src/tools.ts "src/tools.ts.backup.$(date +%Y%m%d%H%M%S)"
cp src/agent.ts "src/agent.ts.backup.$(date +%Y%m%d%H%M%S)"

echo
echo "==> 1. Installing persistent browser bridge..."

cat > browser_tool_bridge.py <<'PY'
#!/usr/bin/env python3

import asyncio
import json
import os
import signal
from typing import Any

from aiohttp import web

from browser_engine import PlaywrightBrowserEngine
from app_supervisor import ProcessSupervisor


HOST = os.getenv("TRAVELER_BROWSER_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.getenv("TRAVELER_BROWSER_BRIDGE_PORT", "8091"))


class BrowserToolBridge:
    def __init__(self) -> None:
        self.browser = PlaywrightBrowserEngine(headless=True)
        self.supervisor = ProcessSupervisor()
        self.started = False

    async def initialize(self) -> None:
        if not self.started:
            await self.browser.start()
            self.started = True

    async def shutdown(self) -> None:
        try:
            await self.supervisor.stop_app()
        finally:
            if self.started:
                await self.browser.close()
                self.started = False

    async def execute(
        self,
        name: str,
        arguments: dict[str, Any],
    ) -> dict[str, Any]:

        await self.initialize()

        if name == "supervisor_start_app":
            return await self.supervisor.start_app(
                command=str(arguments["command"]),
                directory=str(arguments["directory"]),
                port=int(arguments["port"]),
            )

        if name == "supervisor_stop_app":
            return await self.supervisor.stop_app()

        if name == "supervisor_logs":
            return {
                "status": "success",
                "logs": self.supervisor.get_logs(),
            }

        if name == "browser_navigate":
            return await self.browser.navigate(
                str(arguments["url"])
            )

        if name == "browser_click":
            return await self.browser.click_element(
                str(arguments["selector"])
            )

        if name == "browser_state":
            return await self.browser.interrogate_page_state()

        if name == "browser_screenshot":
            if not self.browser.page:
                raise RuntimeError("Browser page is not initialized.")

            output_path = str(
                arguments.get(
                    "path",
                    "/tmp/traveler-browser-screenshot.png",
                )
            )

            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            await self.browser.page.screenshot(
                path=output_path,
                full_page=True,
            )

            return {
                "status": "success",
                "path": output_path,
                "url": self.browser.page.url,
            }

        if name == "browser_text":
            if not self.browser.page:
                raise RuntimeError("Browser page is not initialized.")

            selector = str(arguments["selector"])

            locator = self.browser.page.locator(selector)

            return {
                "status": "success",
                "selector": selector,
                "text": await locator.inner_text(),
            }

        if name == "browser_diagnostics":
            return {
                "status": "success",
                "diagnostics": self.browser.get_and_clear_diagnostics(),
            }

        raise RuntimeError(f"Unknown browser bridge tool: {name}")


bridge = BrowserToolBridge()


async def health(request: web.Request) -> web.Response:
    return web.json_response(
        {
            "status": "ok",
            "service": "traveler-dev-browser-tool-bridge",
            "available": True,
            "port": PORT,
        }
    )


async def tool(request: web.Request) -> web.Response:
    try:
        payload = await request.json()

        name = payload.get("name")
        arguments = payload.get("arguments", {})

        if not isinstance(name, str) or not name:
            raise ValueError("Tool name is required.")

        if not isinstance(arguments, dict):
            raise ValueError("Tool arguments must be an object.")

        result = await bridge.execute(name, arguments)

        return web.json_response(
            {
                "status": "success",
                "tool": name,
                "result": result,
            }
        )

    except Exception as exc:
        return web.json_response(
            {
                "status": "error",
                "tool": payload.get("name") if "payload" in locals() else None,
                "error": str(exc),
            },
            status=500,
        )


async def cleanup(app: web.Application) -> None:
    await bridge.shutdown()


def main() -> None:
    app = web.Application()

    app.router.add_get("/health", health)
    app.router.add_post("/tool", tool)

    app.on_cleanup.append(cleanup)

    print(
        f"TRAVELER DEV browser tool bridge listening on "
        f"http://{HOST}:{PORT}",
        flush=True,
    )

    web.run_app(
        app,
        host=HOST,
        port=PORT,
        handle_signals=True,
    )


if __name__ == "__main__":
    main()
PY

chmod +x browser_tool_bridge.py

echo "PASS: Browser bridge created."

echo
echo "==> 2. Patching TypeScript tool definitions..."

python3 <<'PY'
from pathlib import Path

p = Path("src/tools.ts")
text = p.read_text()

marker = """  {
    type: 'function',
    function: {
      name: 'run_command',
"""

if marker not in text:
    raise SystemExit(
        "ABORT: Expected run_command tool definition was not found."
    )

browser_defs = r"""
  {
    type: 'function',
    function: {
      name: 'supervisor_start_app',
      description:
        'Start a real application process in the workspace and wait until its HTTP endpoint is reachable.',
      parameters: {
        type: 'object',
        properties: {
          command: { type: 'string', minLength: 1 },
          directory: { type: 'string', minLength: 1 },
          port: { type: 'integer', minimum: 1, maximum: 65535 },
        },
        required: ['command', 'directory', 'port'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'supervisor_stop_app',
      description:
        'Stop the currently running real application process.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'supervisor_logs',
      description:
        'Read logs captured from the currently supervised application process.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_navigate',
      description:
        'Navigate the real Playwright Chromium browser to a live application URL and collect runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', minLength: 1 },
        },
        required: ['url'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_click',
      description:
        'Click a real element in the Playwright browser and collect resulting runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string', minLength: 1 },
        },
        required: ['selector'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_state',
      description:
        'Inspect the real browser URL, page title, and runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_text',
      description:
        'Read rendered text from a real element in the Playwright browser.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string', minLength: 1 },
        },
        required: ['selector'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_screenshot',
      description:
        'Capture a real screenshot of the currently loaded application for visual verification.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', minLength: 1 },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_diagnostics',
      description:
        'Retrieve and clear real Playwright console, page, and network diagnostics.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
"""

text = text.replace(marker, browser_defs + marker, 1)

p.write_text(text)
print("PASS: Browser tools added to TOOL_DEFINITIONS.")
PY

echo
echo "==> 3. Patching TypeScript executeTool()..."

python3 <<'PY'
from pathlib import Path

p = Path("src/tools.ts")
text = p.read_text()

needle = """      } else {
        return { status: 'error', message: `Unknown tool: ${toolName}` };
      }
"""

if needle not in text:
    raise SystemExit(
        "ABORT: Expected executeTool() terminal branch was not found. "
        "No executeTool modification made."
    )

bridge_code = r"""      } else if (
        [
          'supervisor_start_app',
          'supervisor_stop_app',
          'supervisor_logs',
          'browser_navigate',
          'browser_click',
          'browser_state',
          'browser_text',
          'browser_screenshot',
          'browser_diagnostics',
        ].includes(toolName)
      ) {
        const bridgeUrl =
          process.env.TRAVELER_BROWSER_BRIDGE_URL ||
          'http://127.0.0.1:8091';

        const bridgeResponse = await fetch(
          `${bridgeUrl}/tool`,
          {
            method: 'POST',
            headers: {
              'content-type': 'application/json',
            },
            body: JSON.stringify({
              name: toolName,
              arguments,
            }),
          },
        );

        const bridgeText = await bridgeResponse.text();

        let bridgePayload: unknown;

        try {
          bridgePayload = JSON.parse(bridgeText);
        } catch {
          throw new Error(
            `Browser bridge returned invalid JSON: ${bridgeText}`,
          );
        }

        if (!bridgeResponse.ok) {
          throw new Error(
            `Browser bridge failed (${bridgeResponse.status}): ${JSON.stringify(
              bridgePayload,
            )}`,
          );
        }

        return bridgePayload;
"""

text = text.replace(needle, bridge_code + needle, 1)

p.write_text(text)
print("PASS: executeTool() now routes browser tools to the persistent bridge.")
PY

echo
echo "==> 4. Verifying browser tool definitions..."

grep -q "supervisor_start_app" src/tools.ts
grep -q "browser_navigate" src/tools.ts
grep -q "browser_click" src/tools.ts
grep -q "browser_diagnostics" src/tools.ts
grep -q "TRAVELER_BROWSER_BRIDGE_URL" src/tools.ts

echo "PASS: TypeScript browser integration detected."

echo
echo "==> 5. Patching model text-tool-call compatibility..."

python3 <<'PY'
from pathlib import Path

p = Path("src/agent.ts")
text = p.read_text()

needle = """  const toolPattern = /<tool_call>([\\s\\S]*?)<\\/tool_call>/g;
"""

if needle not in text:
    raise SystemExit(
        "ABORT: Expected <tool_call> parser was not found in src/agent.ts."
    )

replacement = r"""  const toolPattern = /<tool_call>([\s\S]*?)<\/tool_call>/g;
"""

text = text.replace(needle, replacement, 1)

old_section = """  const toolMatches = Array.from(content.matchAll(toolPattern));

  if (toolMatches.length > 0) {
"""

new_section = r"""  const toolMatches = Array.from(content.matchAll(toolPattern));

  // Compatibility with models emitting:
  // <|tool_call_start|>[read_file(path='...')]<|tool_call_end|>
  // The parser converts only syntactically recognizable calls and never
  // executes arbitrary model text as a shell command.
  const nativeStylePattern =
    /<\|tool_call_start\|>\s*\[([A-Za-z_][A-Za-z0-9_]*)\(([\s\S]*?)\)\]\s*<\|tool_call_end\|>/g;

  const nativeStyleMatches = Array.from(
    content.matchAll(nativeStylePattern),
  );

  for (const match of nativeStyleMatches) {
    const name = match[1];
    const rawArgs = match[2].trim();

    const argumentsObject: Record<string, unknown> = {};

    if (rawArgs.length > 0) {
      const argumentPattern =
        /([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^,\s]+))/g;

      for (const argument of rawArgs.matchAll(argumentPattern)) {
        argumentsObject[argument[1]] =
          argument[2] ?? argument[3] ?? argument[4];
      }
    }

    calls.push({
      name,
      arguments: argumentsObject,
    });
  }

  if (toolMatches.length > 0) {
"""

if old_section not in text:
    raise SystemExit(
        "ABORT: Expected toolMatches processing section was not found."
    )

text = text.replace(old_section, new_section, 1)

p.write_text(text)
print("PASS: Model-specific tool-call compatibility added.")
PY

echo
echo "==> 6. Compiling TypeScript..."

npm run build

echo
echo "==> 7. Starting browser bridge..."

pkill -f 'browser_tool_bridge.py' 2>/dev/null || true

nohup python3 browser_tool_bridge.py \
  > browser_bridge.log 2>&1 &

BRIDGE_PID=$!

echo "$BRIDGE_PID" > browser_bridge.pid

sleep 3

curl -fsS http://127.0.0.1:8091/health

echo
echo "PASS: Persistent Playwright bridge is healthy."

echo
echo "==> 8. Restarting Node agent runtime..."

pkill -9 -f 'node.*dist/server.js' 2>/dev/null || true

sleep 1

nohup node dist/server.js \
  > runtime.log 2>&1 &

RUNTIME_PID=$!

echo "$RUNTIME_PID" > runtime.pid

sleep 3

curl -fsS http://127.0.0.1:8090/health

echo
echo "PASS: Node runtime is healthy."

echo
echo "============================================================"
echo "BROWSER AGENT INTEGRATION REPAIR COMPLETE"
echo "============================================================"
echo
echo "Node runtime : http://127.0.0.1:8090"
echo "Browser bridge: http://127.0.0.1:8091"
echo
echo "Backups:"
ls -1t src/tools.ts.backup.* src/agent.ts.backup.* | head -2
