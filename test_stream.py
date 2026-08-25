import httpx
import json

payload = {
    "prompt": "Write a python function to compute fibonacci numbers efficiently.",
    "model": "anthropic/claude-3.5-sonnet"
}

print("Starting SSE stream...\n")
with httpx.stream("POST", "http://127.0.0.1:8000/api/agent/code/stream", json=payload, timeout=60.0) as response:
    for line in response.iter_lines():
        if line.startswith("data: "):
            data_str = line[6:].strip()
            if data_str == "[DONE]":
                print("\n\n--- Stream finished ---")
                break
            try:
                event = json.loads(data_str)
                if "content" in event:
                    print(event["content"], end="", flush=True)
                elif "error" in event:
                    print("\nError:", event["error"])
            except json.JSONDecodeError:
                pass
