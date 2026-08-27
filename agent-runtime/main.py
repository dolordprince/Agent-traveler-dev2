import asyncio
from browser_engine import PlaywrightBrowserEngine
from agent_tools import AgentBrowserToolSet

async def run_agent_browser_loop():
    # Initialize engine (supports custom system chromium path if running on custom Linux environment)
    engine = PlaywrightBrowserEngine(headless=True)
    await engine.start()
    
    tools = AgentBrowserToolSet(engine)

    try:
        print("--- [Agent Action]: Navigating to target ---")
        nav_res = await tools.execute_tool("browser_navigate", {"url": "https://example.com"})
        print(f"Result: {nav_res}\n")

        print("--- [Agent Interrogation]: Fetching DOM & Accessibility Tree ---")
        state_res = await tools.execute_tool("browser_interrogate_state", {})
        print(f"State Summary:\n{state_res[:400]}... [truncated]\n")

        print("--- [Agent Interrogation]: CDP Command (DOM.getDocument) ---")
        cdp_res = await tools.execute_tool("browser_cdp_command", {
            "method": "DOM.getDocument",
            "params": {"depth": 1}
        })
        print(f"CDP Result:\n{cdp_res[:300]}... [truncated]\n")

    finally:
        await engine.close()
        print("--- Browser closed cleanly ---")

if __name__ == "__main__":
    asyncio.run(run_agent_browser_loop())
