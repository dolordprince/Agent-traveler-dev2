#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "============================================================"
echo "TRAVELER DEV — PRODUCTION TOOL EXECUTION REPAIR V2"
echo "============================================================"

test -f src/agent.ts
test -f src/tools.ts
test -f browser_engine.py
test -f app_supervisor.py

STAMP="$(date +%Y%m%d%H%M%S)"

cp src/agent.ts "src/agent.ts.pre-tool-repair.${STAMP}"
cp src/tools.ts "src/tools.ts.pre-tool-repair.${STAMP}"

echo
echo "==> 1. Installing production browser bridge..."

cat > browser_tool_bridge.py <<'PY'
#!/usr/bin/env python3

import asyncio
import os
from typing import Any

from aiohttp import web

from browser_engine import PlaywrightBrowserEngine
from app_supervisor import ProcessSupervisor


HOST = os.getenv(
    "TRAVELER_BROWSER_BRIDGE_HOST",
    "127.0.0.1",
)

PORT = int(
    os.getenv(
        "TRAVELER_BROWSER_BRIDGE_PORT",
        "8091",
    )
)


class BrowserBridge:
    def __init__(self) -> None:
        self.browser = PlaywrightBrowserEngine(headless=True)
        self.supervisor = ProcessSupervisor()
        self.started = False

    async def start(self) -> None:
        if self.started:
            return

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

        await self.start()

        if name == "supervisor_start_app":
            return await self.supervisor.start_app(
                str(arguments["command"]),
                str(arguments["directory"]),
                int(arguments["port"]),
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

        if name == "browser_text":
            if not self.browser.page:
                raise RuntimeError(
                    "Browser page is not initialized."
                )

            selector = str(arguments["selector"])

            locator = self.browser.page.locator(selector)

            return {
                "status": "success",
                "selector": selector,
                "text": await locator.inner_text(),
            }

        if name == "browser_screenshot":
            if not self.browser.page:
                raise RuntimeError(
                    "Browser page is not initialized."
                )

            screenshot_path = str(
                arguments.get(
                    "path",
                    "/tmp/traveler-browser.png",
                )
            )

            directory = os.path.dirname(
                os.path.abspath(screenshot_path)
            )

            os.makedirs(directory, exist_ok=True)

            await self.browser.page.screenshot(
                path=screenshot_path,
                full_page=True,
            )

            return {
                "status": "success",
                "path": screenshot_path,
                "url": self.browser.page.url,
            }

        if name == "browser_diagnostics":
            return {
                "status": "success",
                "diagnostics":
                    self.browser.get_and_clear_diagnostics(),
            }

        raise RuntimeError(
            f"Unknown browser tool: {name}"
        )


bridge = BrowserBridge()


async def health(
    request: web.Request,
) -> web.Response:

    return web.json_response(
        {
            "status": "ok",
            "service":
                "traveler-dev-browser-tool-bridge",
            "available": True,
            "host": HOST,
            "port": PORT,
        }
    )


async def execute_tool(
    request: web.Request,
) -> web.Response:

    try:
        payload = await request.json()

        name = payload.get("name")
        arguments = payload.get(
            "arguments",
            {},
        )

        if not isinstance(name, str) or not name:
            raise ValueError(
                "Tool name must be a non-empty string."
            )

        if not isinstance(arguments, dict):
            raise ValueError(
                "Tool arguments must be an object."
            )

        result = await bridge.execute(
            name,
            arguments,
        )

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
                "error": str(exc),
            },
            status=500,
        )


async def cleanup(
    app: web.Application,
) -> None:

    await bridge.shutdown()


def main() -> None:

    app = web.Application()

    app.router.add_get(
        "/health",
        health,
    )

    app.router.add_post(
        "/tool",
        execute_tool,
    )

    app.on_cleanup.append(cleanup)

    print(
        f"TRAVELER DEV browser bridge listening "
        f"on http://{HOST}:{PORT}",
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

echo "PASS: Browser bridge source installed."

echo
echo "==> 2. Replacing agent parser with multi-format production parser..."

python3 <<'PY'
from pathlib import Path

p = Path("src/agent.ts")
text = p.read_text()

start = text.index("function parseJsonObjects(")
end = text.index(
    "export async function runTravelerAgent(",
    start,
)

replacement = r'''
function parseJsonObjects(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  let depth = 0;
  let startIndex = -1;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }

      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') {
      if (depth === 0) {
        startIndex = i;
      }

      depth += 1;
      continue;
    }

    if (char === '}') {
      depth -= 1;

      if (
        depth === 0 &&
        startIndex !== -1
      ) {
        const candidate = text.slice(
          startIndex,
          i + 1,
        );

        try {
          const parsed = JSON.parse(candidate) as {
            name?: unknown;
            arguments?: unknown;
          };

          if (
            typeof parsed.name === 'string' &&
            parsed.arguments !== null &&
            typeof parsed.arguments === 'object'
          ) {
            results.push({
              name: parsed.name,
              arguments:
                parsed.arguments as Record<
                  string,
                  unknown
                >,
            });
          }
        } catch {
          // Ignore unrelated JSON.
        }

        startIndex = -1;
      }
    }
  }

  return results;
}


function parseParameterValue(
  value: string,
): unknown {
  const trimmed = value.trim();

  if (
    trimmed.startsWith('"') &&
    trimmed.endsWith('"')
  ) {
    return trimmed.slice(1, -1);
  }

  if (
    trimmed.startsWith("'") &&
    trimmed.endsWith("'")
  ) {
    return trimmed.slice(1, -1);
  }

  if (trimmed === 'true') {
    return true;
  }

  if (trimmed === 'false') {
    return false;
  }

  if (trimmed === 'null') {
    return null;
  }

  if (
    /^-?\d+(\.\d+)?$/.test(trimmed)
  ) {
    return Number(trimmed);
  }

  return trimmed;
}


function parseFunctionSyntax(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const pattern =
    /<\|tool_call_start\|>\s*\[([A-Za-z_][A-Za-z0-9_]*)\(([\s\S]*?)\)\]\s*<\|tool_call_end\|>/g;

  for (const match of text.matchAll(pattern)) {
    const name = match[1];
    const rawArguments = match[2].trim();

    const argumentsObject:
      Record<string, unknown> = {};

    if (rawArguments.length > 0) {
      const argumentPattern =
        /([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:"((?:\\.|[^"])*)"|'((?:\\.|[^'])*)'|([^,]+))/g;

      for (
        const argument of
        rawArguments.matchAll(argumentPattern)
      ) {
        const raw =
          argument[2] ??
          argument[3] ??
          argument[4] ??
          '';

        argumentsObject[argument[1]] =
          parseParameterValue(raw);
      }
    }

    results.push({
      name,
      arguments: argumentsObject,
    });
  }

  return results;
}


function parseFunctionXml(
  text: string,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const results: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const functionPattern =
    /<function=([A-Za-z_][A-Za-z0-9_]*)>([\s\S]*?)<\/function>/g;

  for (
    const functionMatch of
    text.matchAll(functionPattern)
  ) {
    const name = functionMatch[1];
    const body = functionMatch[2];

    const argumentsObject:
      Record<string, unknown> = {};

    const parameterPattern =
      /<parameter=([A-Za-z_][A-Za-z0-9_]*)>\s*([\s\S]*?)\s*<\/parameter>/g;

    for (
      const parameterMatch of
      body.matchAll(parameterPattern)
    ) {
      argumentsObject[
        parameterMatch[1]
      ] = parseParameterValue(
        parameterMatch[2],
      );
    }

    results.push({
      name,
      arguments: argumentsObject,
    });
  }

  return results;
}


function extractToolCalls(
  content: string,
  nativeCalls?: Array<{
    id?: string;
    type?: string;
    function?: {
      name?: string;
      arguments?: string;
    };
  }>,
): Array<{
  name: string;
  arguments: Record<string, unknown>;
}> {
  const calls: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  if (
    Array.isArray(nativeCalls) &&
    nativeCalls.length > 0
  ) {
    for (const call of nativeCalls) {
      if (!call.function?.name) {
        continue;
      }

      let parsedArgs:
        Record<string, unknown> = {};

      if (call.function.arguments) {
        try {
          parsedArgs = JSON.parse(
            call.function.arguments,
          ) as Record<string, unknown>;
        } catch {
          parsedArgs = {};
        }
      }

      calls.push({
        name: call.function.name,
        arguments: parsedArgs,
      });
    }
  }

  calls.push(
    ...parseFunctionXml(content),
  );

  calls.push(
    ...parseFunctionSyntax(content),
  );

  const taggedPattern =
    /<tool_call>\s*([\s\S]*?)\s*<\/tool_call>/g;

  for (
    const match of content.matchAll(taggedPattern)
  ) {
    calls.push(
      ...parseJsonObjects(match[1]),
    );
  }

  if (calls.length === 0) {
    calls.push(
      ...parseJsonObjects(content),
    );
  }

  const unique: Array<{
    name: string;
    arguments: Record<string, unknown>;
  }> = [];

  const seen = new Set<string>();

  for (const call of calls) {
    const key =
      `${call.name}:${JSON.stringify(call.arguments)}`;

    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    unique.push(call);
  }

  return unique;
}


'''

p.write_text(
    text[:start] +
    replacement +
    text[end:],
)

print("PASS: Multi-format tool parser installed.")
PY

echo
echo "==> 3. Updating agent system contract..."

python3 <<'PY'
from pathlib import Path

p = Path("src/agent.ts")
text = p.read_text()

old = """RULES:
1. Every tool call MUST be enclosed in <tool_call> tags and contain ONE valid JSON object.
2. If you need to invoke multiple tools, you can use multiple separate <tool_call>...</tool_call> tags.
3. Always verify file creation and run test/build commands before concluding.`;

"""

new = """RULES:
1. Use the provided tools for all real workspace operations.
2. Never claim a tool was executed unless the runtime returned its result.
3. Tool calls may be emitted using native tool calls, <tool_call> JSON, function XML, or the model's native <|tool_call_start|> syntax.
4. Continue executing until the requested work is actually completed.
5. For application development, inspect the workspace before modifying it.
6. For browser verification, start the real application, navigate with Playwright, interact with the rendered application, inspect diagnostics, repair failures, and retest.
7. Never substitute file inspection for browser verification.
8. Always verify file creation and run appropriate build/test commands before concluding.
9. Do not fabricate URLs, test results, deployment results, or successful tool execution.`;

"""

if old not in text:
    raise SystemExit(
        "ABORT: Existing SYSTEM_INSTRUCTIONS rules block not found."
    )

p.write_text(text.replace(old, new, 1))

print("PASS: Agent execution contract strengthened.")
PY

echo
echo "==> 4. Compiling runtime..."

npm run build

echo
echo "==> 5. Stopping only existing bridge processes..."

if [[ -f browser_bridge.pid ]]; then
    OLD_PID="$(cat browser_bridge.pid || true)"

    if [[ "$OLD_PID" =~ ^[0-9]+$ ]] &&
       kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi

    rm -f browser_bridge.pid
fi

echo
echo "==> 6. Starting browser bridge safely..."

nohup python3 browser_tool_bridge.py \
    > browser_bridge.log 2>&1 < /dev/null &

BRIDGE_PID=$!

echo "$BRIDGE_PID" > browser_bridge.pid

sleep 4

if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
    echo "ERROR: Browser bridge exited during startup."
    cat browser_bridge.log
    exit 1
fi

curl --fail --silent --show-error \
    http://127.0.0.1:8091/health

echo
echo "PASS: Browser bridge is running."

echo
echo "==> 7. Restarting Node runtime safely..."

if [[ -f runtime.pid ]]; then
    OLD_PID="$(cat runtime.pid || true)"

    if [[ "$OLD_PID" =~ ^[0-9]+$ ]] &&
       kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi

    rm -f runtime.pid
fi

TRAVELER_BROWSER_BRIDGE_URL="${TRAVELER_BROWSER_BRIDGE_URL:-http://127.0.0.1:8091}"

export TRAVELER_BROWSER_BRIDGE_URL

nohup node dist/server.js \
    > runtime.log 2>&1 < /dev/null &

RUNTIME_PID=$!

echo "$RUNTIME_PID" > runtime.pid

sleep 3

if ! kill -0 "$RUNTIME_PID" 2>/dev/null; then
    echo "ERROR: Node runtime exited during startup."
    cat runtime.log
    exit 1
fi

curl --fail --silent --show-error \
    http://127.0.0.1:8090/health

echo
echo
echo "============================================================"
echo "PRODUCTION TOOL EXECUTION REPAIR COMPLETE"
echo "============================================================"
echo
echo "Runtime PID : $RUNTIME_PID"
echo "Bridge PID  : $BRIDGE_PID"
echo "Runtime     : http://127.0.0.1:8090"
echo "Bridge      : http://127.0.0.1:8091"
