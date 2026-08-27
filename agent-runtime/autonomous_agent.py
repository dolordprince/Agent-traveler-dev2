import asyncio
import json
import os
from openai import AsyncOpenAI
from browser_engine import PlaywrightBrowserEngine
from agent_tools import AgentBrowserToolSet

# Initialize client. Note: To use vision, ensure your model supports multimodal inputs 
# (e.g., gpt-4o, claude-3-5-sonnet via OpenRouter, or a local llava/qwen-vl via Ollama)
client = AsyncOpenAI(
    api_key=os.getenv("OPENAI_API_KEY", "your-api-key-here")
)

FINISH_TOOL = {
    "type": "function",
    "function": {
        "name": "finish_task",
        "description": "Call this tool when the final objective has been successfully achieved or if it's impossible to complete.",
        "parameters": {
            "type": "object",
            "properties": {
                "summary": {"type": "string", "description": "Final result or summary of findings."}
            },
            "required": ["summary"]
        }
    }
}

async def run_autonomous_loop(goal: str, max_steps: int = 15):
    engine = PlaywrightBrowserEngine(headless=True)
    await engine.start()
    toolset = AgentBrowserToolSet(engine)

    tools_schema = [{"type": "function", "function": t} for t in toolset.get_tool_declarations()]
    tools_schema.append(FINISH_TOOL)

    messages = [
        {
            "role": "system",
            "content": (
                "You are an autonomous multimodal Web Automation Agent.\n"
                "Rules:\n"
                "1. Check the page state (`browser_interrogate_state`) to read the DOM structurally.\n"
                "2. If the DOM is complex, obscure, or you need spatial/visual confirmation, call `browser_capture_vision` to literally see the page.\n"
                "3. Perform precise actions (`browser_navigate`, `browser_click`, `browser_type`).\n"
                "4. When the user's objective is satisfied, call `finish_task`."
            )
        },
        {"role": "user", "content": f"Goal: {goal}"}
    ]

    print(f"🎯 Objective: {goal}\n" + "="*50)

    try:
        for step in range(1, max_steps + 1):
            print(f"\n🔄 --- [Step {step}/{max_steps}] Requesting LLM Action ---")

            response = await client.chat.completions.create(
                model="gpt-4o", # Must be a vision-capable model
                messages=messages,
                tools=tools_schema,
                tool_choice="auto",
                max_tokens=1000
            )

            response_message = response.choices[0].message
            messages.append(response_message)

            if response_message.content:
                print(f"🤖 LLM Thought: {response_message.content}")

            tool_calls = response_message.tool_calls
            if not tool_calls:
                print("⚠️ LLM didn't call any tools. Retrying prompt context...")
                continue

            for tool_call in tool_calls:
                function_name = tool_call.function.name
                args = json.loads(tool_call.function.arguments)

                print(f"🛠️ Executing: {function_name}({args})")

                if function_name == "finish_task":
                    print("\n" + "="*50)
                    print(f"🎉 TASK FINISHED! Summary:\n{args.get('summary')}")
                    return

                result = await toolset.execute_tool(function_name, args)

                # Special handling for Vision Tool
                if function_name == "browser_capture_vision":
                    result_dict = json.loads(result)
                    
                    if result_dict.get("status") == "success":
                        b64_img = result_dict.pop("image_base64")
                        
                        # 1. Acknowledge the tool execution successfully
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": json.dumps({"status": "success", "message": "Screenshot captured. See the accompanying user message."})
                        })
                        
                        # 2. Inject the Base64 image payload as a multimodal user message
                        messages.append({
                            "role": "user",
                            "content": [
                                {"type": "text", "text": "Here is the visual capture of the page viewport you just requested:"},
                                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_img}", "detail": "high"}}
                            ]
                        })
                        print("👁️ Visual payload successfully injected into model context.")
                    else:
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": result
                        })
                        
                else:
                    # Standard Text Tool Handling
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tool_call.id,
                        "content": result
                    })
                    
                    display_res = result[:200] + "..." if len(result) > 200 else result
                    print(f"📥 Tool Output: {display_res}")

        print("❌ Reached maximum step limit without completion.")

    finally:
        await engine.close()
        print("\n--- Browser runtime shutdown ---")

if __name__ == "__main__":
    USER_GOAL = "Navigate to https://news.ycombinator.com/. Take a screenshot and tell me what the top story is by looking at the page."
    asyncio.run(run_autonomous_loop(USER_GOAL))
