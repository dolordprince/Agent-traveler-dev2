import httpx
import json
from typing import AsyncGenerator
from app.config import *

class LLMGateway:
    def __init__(self):
        self.clients = {
            "groq": {"url": "https://api.groq.com/openai/v1/chat/completions", "key": GROQ_API_KEY, "models_url": "https://api.groq.com/openai/v1/models"},
            "cerebras": {"url": "https://api.cerebras.ai/v1/chat/completions", "key": CEREBRAS_API_KEY},
            "openrouter": {"url": "https://openrouter.ai/api/v1/chat/completions", "key": OPENROUTER_API_KEY},
        }
        self.groq_models = [GROQ_PRIMARY_MODEL, GROQ_FALLBACK_MODEL]

    async def validate_models(self):
        """Runtime model discovery to avoid stale IDs"""
        if not self.clients["groq"]["key"]: return
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                r = await client.get(self.clients["groq"]["models_url"], headers={"Authorization": f"Bearer {self.clients['groq']['key']}"})
                available = [m["id"] for m in r.json().get("data", [])]
                # keep only models that exist
                self.groq_models = [m for m in self.groq_models if m in available]
                if not self.groq_models: self.groq_models = available[:2]
                print(f"Groq models validated: {self.groq_models}")
        except: pass

    async def stream_chat(self, provider: str, model: str, messages: list) -> AsyncGenerator[str, None]:
        if provider == "groq": await self.validate_models()

        cfg = self.clients.get(provider)
        if not cfg or not cfg["key"]:
            yield f"data: ERROR: No API key for {provider}\n\n"
            return

        # fallback logic
        if provider == "groq" and model not in self.groq_models:
            model = self.groq_models[0] if self.groq_models else model

        payload = {"model": model, "messages": messages, "stream": True}
        headers = {"Authorization": f"Bearer {cfg['key']}"}

        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream("POST", cfg["url"], json=payload, headers=headers) as resp:
                async for line in resp.aiter_lines():
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]":
                            yield "data: [DONE]\n\n"
                            continue
                        try:
                            obj = json.loads(data)
                            delta = obj["choices"][0]["delta"]
                            # GPT-OSS sends reasoning separately. We merge it
                            content = delta.get("content", "") or delta.get("reasoning", "")
                            if content:
                                yield f"data: {json.dumps({'content': content})}\n\n"
                        except:
                            yield line + "\n\n"

gateway = LLMGateway()
