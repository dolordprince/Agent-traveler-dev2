import httpx

payload = {
    "prompt": "List the files in the current working directory and read main.py to verify its setup.",
    "model": "anthropic/claude-3.5-sonnet",
    "enable_mcp": True
}

try:
    print("Sending MCP tool-enabled request...\n")
    res = httpx.post("http://127.0.0.1:8000/api/agent/mcp", json=payload, timeout=60.0)
    print("Status:", res.status_code)
    data = res.json()
    print("\n--- MCP Tool Executions ---")
    for call in data.get("mcp_tool_calls", []):
        print(f"Tool: {call['tool']} | Args: {call['args']}")
    print("\n--- Final Agent Answer ---")
    print(data.get("content"))
except Exception as e:
    print("Error connecting to server:", e)
