import httpx

payload = {
    "prompt": "List the tables in the connected database or list accessible repositories.",
    "model": "anthropic/claude-3.5-sonnet"
}

try:
    print("Testing external Stdio MCP transport...\n")
    res = httpx.post("http://127.0.0.1:8000/api/agent/mcp-stdio", json=payload, timeout=60.0)
    print("Status Code:", res.status_code)
    print("Response JSON:", res.json())
except Exception as e:
    print("Error:", e)
