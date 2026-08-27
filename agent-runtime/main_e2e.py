import asyncio
import os
import json
from browser_engine import PlaywrightBrowserEngine
from app_supervisor import ProcessSupervisor
from agent_tools import AgentWorkflowTools

async def run_e2e_verification_test():
    # Setup test workspace
    os.makedirs("./test_workspace", exist_ok=True)
    with open("./test_workspace/index.html", "w") as f:
        f.write("""
        <html>
            <body>
                <h1>E2E Test Subject</h1>
                <button id="broken-btn">Click Me for Runtime Error</button>
                <script>
                    document.getElementById('broken-btn').addEventListener('click', () => {
                        console.error('CRITICAL: TypeError: Cannot read properties of undefined (reading price)');
                        fetch('/api/missing-endpoint');
                    });
                </script>
            </body>
        </html>
        """)

    print("🚀 Initializing Agent Supervisors...")
    browser = PlaywrightBrowserEngine(headless=True)
    supervisor = ProcessSupervisor()
    await browser.start()
    tools = AgentWorkflowTools(browser, supervisor)

    try:
        # Step 1: Start App Process
        print("\n--- [1] Agent starting App Server ---")
        start_res = await tools.execute_tool("supervisor_start_app", {
            "command": "python3 -m http.server 3005",
            "directory": "./test_workspace",
            "port": 3005
        })
        print(f"Result: {start_res}")

        # Step 2: Navigate and Verify
        target_url = json.loads(start_res).get("url")
        print(f"\n--- [2] Agent Navigating via Playwright to {target_url} ---")
        nav_res = await tools.execute_tool("browser_navigate", {"url": target_url})
        print(f"Result: {nav_res}")

        # Step 3: Trigger broken Interaction to collect Diagnostics
        print("\n--- [3] Agent Clicking Broken Component (Auto-Repair Trigger) ---")
        click_res = await tools.execute_tool("browser_click", {"selector": "#broken-btn"})
        print(f"Result: {click_res}")

    finally:
        # Cleanup
        print("\n--- Cleaning up resources ---")
        await tools.execute_tool("supervisor_stop_app", {})
        await browser.close()
        print("Shutdown complete.")

if __name__ == "__main__":
    asyncio.run(run_e2e_verification_test())
