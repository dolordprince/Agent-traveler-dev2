import json
from typing import Any, Dict
from browser_engine import PlaywrightBrowserEngine
from app_supervisor import ProcessSupervisor

class AgentWorkflowTools:
    def __init__(self, browser: PlaywrightBrowserEngine, supervisor: ProcessSupervisor):
        self.browser = browser
        self.supervisor = supervisor

    def get_tool_declarations(self) -> list:
        return [
            {
                "name": "supervisor_start_app",
                "description": "Start a local application process (e.g., Python web server, npm start) and wait for it to be accessible via localhost.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string", "description": "e.g., 'python3 -m http.server 8000'"},
                        "directory": {"type": "string", "description": "Directory to run command from"},
                        "port": {"type": "integer", "description": "Port to poll for readiness (e.g., 8000)"}
                    },
                    "required": ["command", "directory", "port"]
                }
            },
            {
                "name": "supervisor_stop_app",
                "description": "Stop the currently running background application.",
                "parameters": {"type": "object", "properties": {}}
            },
            {
                "name": "browser_navigate",
                "description": "Open Playwright and navigate to a URL to test the live app.",
                "parameters": {
                    "type": "object",
                    "properties": {"url": {"type": "string"}},
                    "required": ["url"]
                }
            },
            {
                "name": "browser_click",
                "description": "Click an element inside the Playwright testing window. Returns resulting diagnostics.",
                "parameters": {
                    "type": "object",
                    "properties": {"selector": {"type": "string"}},
                    "required": ["selector"]
                }
            }
        ]

    async def execute_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        try:
            if tool_name == "supervisor_start_app":
                res = await self.supervisor.start_app(arguments["command"], arguments["directory"], arguments["port"])
                return json.dumps(res)
            elif tool_name == "supervisor_stop_app":
                res = await self.supervisor.stop_app()
                return json.dumps(res)
            elif tool_name == "browser_navigate":
                res = await self.browser.navigate(arguments["url"])
                return json.dumps(res)
            elif tool_name == "browser_click":
                res = await self.browser.click_element(arguments["selector"])
                return json.dumps(res)
            else:
                return json.dumps({"error": f"Unknown tool: {tool_name}"})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})
