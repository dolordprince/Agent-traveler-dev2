import os
import json
import logging
import secrets
from typing import List, Optional
from fastapi import FastAPI, HTTPException, status, Security, Depends
from fastapi.security import APIKeyHeader, HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AI-Gateway")

app = FastAPI(
    title="Production AI Gateway",
    description="OpenAI Compatible Gateway routed via OpenRouter and Groq.",
    version="1.3.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GATEWAY_API_KEY = os.getenv("GATEWAY_API_KEY", "prod-secret-key-12345")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

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
            detail="Invalid or missing API key."
        )
    return provided_key

class ChatMessage(BaseModel):
    role: str
    content: str

class OpenAICompletionRequest(BaseModel):
    model: str = "anthropic/claude-3.5-sonnet"
    messages: List[ChatMessage]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = 4096
    stream: Optional[bool] = False

@app.get("/health")
async def health():
    return {
        "status": "ok", 
        "gateway": "OpenAI Compatible", 
        "openrouter": bool(OPENROUTER_API_KEY),
        "groq": bool(GROQ_API_KEY)
    }

@app.get("/v1/models", dependencies=[Depends(verify_api_key)])
@app.get("/models", dependencies=[Depends(verify_api_key)])
async def list_models():
    return {
        "object": "list",
        "data": [
            {"id": "anthropic/claude-3.5-sonnet", "object": "model", "owned_by": "anthropic"},
            {"id": "llama-3.3-70b-versatile", "object": "model", "owned_by": "meta"},
            {"id": "openai/gpt-4o", "object": "model", "owned_by": "openai"}
        ]
    }

@app.post("/v1/chat/completions", dependencies=[Depends(verify_api_key)])
async def chat_completions(req: OpenAICompletionRequest):
    async with httpx.AsyncClient() as client:
        # Route Llama requests to Groq if key is available, otherwise default to OpenRouter
        if "llama" in req.model.lower() and GROQ_API_KEY:
            url = "https://api.groq.com/openai/v1/chat/completions"
            headers = {"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"}
        else:
            if not OPENROUTER_API_KEY:
                raise HTTPException(status_code=500, detail="OPENROUTER_API_KEY is missing.")
            url = "https://openrouter.ai/api/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://agent-traveler-dev2.onrender.com",
                "X-Title": "Agent Traveler Gateway"
            }

        try:
            res = await client.post(url, headers=headers, json=req.dict(), timeout=60.0)
            if res.status_code != 200:
                logger.error(f"Provider Error [{res.status_code}]: {res.text}")
                raise HTTPException(status_code=res.status_code, detail=res.text)

            if req.stream:
                async def sse_generator():
                    async for chunk in res.aiter_bytes():
                        yield chunk
                return StreamingResponse(sse_generator(), media_type="text/event-stream")
            else:
                return res.json()
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Gateway connection error: {str(exc)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
