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
