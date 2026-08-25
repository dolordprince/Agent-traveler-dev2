import os
import json
import logging
import asyncio
import secrets
from typing import List, Dict, Any, Optional, AsyncGenerator, Union
from fastapi import FastAPI, HTTPException, status, Security, Depends, Request
from fastapi.security import APIKeyHeader, HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AI-Gateway")

app = FastAPI(
    title="Production AI Gateway (OpenAI Compatible)",
    description="Multi-provider AI Gateway supporting Open WebUI and OpenAI API standards.",
    version="1.1.0"
)

# Enable CORS for Open WebUI & Vercel Web UIs
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GATEWAY_API_KEY = os.getenv("GATEWAY_API_KEY", "prod-secret-key-12345")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

# --- Auth ---
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
bearer_scheme = HTTPBearer(auto_error=False)

async def verify_api_key(
    header_key: Optional[str] = Security(api_key_header),
    token: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme)
) -> str:
    provided_key = header_key or (token.credentials if token else None)
    if not provided_key or not secrets.compare_digest(provided_key, GATEWAY_API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Unauthorized", "message": "Invalid or missing API key."}
        )
    return provided_key

# --- OpenAI Request Models ---
class ChatMessage(BaseModel):
    role: str
    content: str

class OpenAICompletionRequest(BaseModel):
    model: str = "anthropic/claude-3.5-sonnet"
    messages: List[ChatMessage]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = 4096
    stream: Optional[bool] = False

# --- Handlers ---
async def fetch_openrouter_completion(client: httpx.AsyncClient, req: OpenAICompletionRequest):
    if not OPENROUTER_API_KEY:
        raise ValueError("Missing OPENROUTER_API_KEY")
    res = await client.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={"Authorization": f"Bearer {OPENROUTER_API_KEY}", "Content-Type": "application/json"},
        json={
            "model": req.model,
            "messages": [m.dict() for m in req.messages],
            "max_tokens": req.max_tokens,
            "temperature": req.temperature,
            "stream": req.stream
        },
        timeout=60.0
    )
    res.raise_for_status()
    return res

# --- OpenAI Standard Endpoints ---

@app.get("/v1/models", dependencies=[Depends(verify_api_key)])
@app.get("/models")
async def list_models():
    """Allows Open WebUI to auto-populate available models."""
    return {
        "object": "list",
        "data": [
            {"id": "anthropic/claude-3.5-sonnet", "object": "model", "owned_by": "anthropic"},
            {"id": "openai/gpt-4o", "object": "model", "owned_by": "openai"},
            {"id": "meta-llama/llama-3.3-70b-instruct", "object": "model", "owned_by": "meta"}
        ]
    }

@app.post("/v1/chat/completions", dependencies=[Depends(verify_api_key)])
async def chat_completions(req: OpenAICompletionRequest):
    """OpenAI-compatible Chat Completion Endpoint for Open WebUI / LibreChat."""
    async with httpx.AsyncClient() as client:
        if req.stream:
            async def sse_generator():
                try:
                    res = await fetch_openrouter_completion(client, req)
                    async for chunk in res.aiter_bytes():
                        yield chunk
                except Exception as e:
                    yield f"data: {json.dumps({'error': str(e)})}\n\n".encode()

            return StreamingResponse(sse_generator(), media_type="text/event-stream")
        else:
            try:
                res = await fetch_openrouter_completion(client, req)
                return res.json()
            except Exception as e:
                raise HTTPException(status_code=502, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "gateway": "OpenAI Compatible"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
