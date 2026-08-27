import asyncio
import base64
import os
from typing import Any, Dict, List, Optional
from playwright.async_api import async_playwright, Browser, BrowserContext, Page, CDPSession

class PlaywrightBrowserEngine:
    def __init__(self, headless: bool = True):
        self.headless = headless
        self.playwright = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None
        self.runtime_diagnostics: List[str] = []

    async def start(self) -> None:
        self.playwright = await async_playwright().start()
        launch_args = [
            "--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage", "--disable-gpu"
        ]
        self.browser = await self.playwright.chromium.launch(headless=self.headless, args=launch_args)
        self.context = await self.browser.new_context(viewport={"width": 1280, "height": 800})
        self.page = await self.context.new_page()
        
        # Attach Diagnostic Listeners
        self.page.on("console", self._handle_console)
        self.page.on("pageerror", self._handle_page_error)
        self.page.on("response", self._handle_network_response)

    def _handle_console(self, msg):
        if msg.type in ["error", "warning"]:
            self.runtime_diagnostics.append(f"[Console {msg.type.upper()}] {msg.text}")
            
    def _handle_page_error(self, err):
        self.runtime_diagnostics.append(f"[Page Error] {err.message}")
        
    def _handle_network_response(self, res):
        if not res.ok:
            self.runtime_diagnostics.append(f"[Network {res.status}] Failed fetch at {res.url}")

    def get_and_clear_diagnostics(self) -> List[str]:
        diags = list(self.runtime_diagnostics)
        self.runtime_diagnostics.clear()
        return diags

    async def close(self) -> None:
        if self.context: await self.context.close()
        if self.browser: await self.browser.close()
        if self.playwright: await self.playwright.stop()

    async def navigate(self, url: str) -> Dict[str, Any]:
        if not self.page: raise RuntimeError("Browser not started.")
        response = await self.page.goto(url, wait_until="networkidle")
        return {
            "url": self.page.url,
            "status": response.status if response else 0,
            "diagnostics": self.get_and_clear_diagnostics()
        }

    async def click_element(self, selector: str) -> Dict[str, Any]:
        if not self.page: raise RuntimeError("Browser not started.")
        await self.page.click(selector, timeout=5000)
        await self.page.wait_for_load_state("networkidle", timeout=2000)
        return {"success": True, "diagnostics": self.get_and_clear_diagnostics()}

    async def interrogate_page_state(self) -> Dict[str, Any]:
        if not self.page: raise RuntimeError("Browser not started.")
        return {
            "url": self.page.url,
            "title": await self.page.title(),
            "diagnostics": self.get_and_clear_diagnostics()
        }
