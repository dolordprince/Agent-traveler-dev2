import logging
import os
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.config import HOST, PORT
from app.providers import chat, provider_status

logger = logging.getLogger("traveler.main")

JOBS: dict[str, Any] = {}


def stop_preview(job_id: str) -> None:
    pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application startup complete.")
    yield
    for job_id in list(JOBS):
        try:
            stop_preview(job_id)
        except Exception:
            logger.exception("Failed stopping preview %s", job_id)


app = FastAPI(title="TRAVELER DEV Agent Gateway", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str | None = None
    messages: list[Message]
    temperature: float = 0.2
    max_tokens: int | None = None


# ─── Root & Health ────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "TRAVELER DEV Agent Gateway",
        "version": "2.0.0",
        "endpoints": [
            "/health",
            "/v1/chat/completions",
            "/v1/vercel/chat/completions",
            "/v1/kilo/chat/completions",
            "/v1/kilo/models",
            "/v1/gemini/chat/completions",
        ]
    }


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "traveler-dev-agent",
        **provider_status(),
    }


# ─── Core Chat ────────────────────────────────────────────────────────────────

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    try:
        raw_messages = [msg.model_dump() for msg in request.messages]
        response = await chat(
            messages=raw_messages,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        )
        return {
            "id": response.get("id", "chatcmpl-default"),
            "object": "chat.completion",
            "model": response.get("model", request.model or "default"),
            "choices": response.get("choices", [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response.get("content", ""),
                    },
                    "finish_reason": "stop",
                }
            ]),
            "usage": response.get("usage", {}),
        }
    except Exception as exc:
        logger.exception("Chat completion request failed")
        raise HTTPException(status_code=500, detail=str(exc))


# ─── Vercel Proxy ─────────────────────────────────────────────────────────────

@app.post("/v1/vercel/chat/completions")
async def vercel_chat_proxy(request: Request):
    from app.providers import _vercel_chat
    body = await request.json()
    messages = body.get("messages", [])
    model = body.get("model", None)
    try:
        result = await _vercel_chat(messages, model)
        return {
            "id": "vercel-proxy",
            "object": "chat.completion",
            "model": result["model"],
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": result["content"]},
                "finish_reason": "stop",
            }],
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


# ─── Kilo Proxy ───────────────────────────────────────────────────────────────

@app.post("/v1/kilo/chat/completions")
async def kilo_chat_proxy(request: Request):
    from app.providers import _kilo_chat
    body = await request.json()
    messages = body.get("messages", [])
    model = body.get("model", None)
    try:
        result = await _kilo_chat(messages, model)
        return {
            "id": "kilo-proxy",
            "object": "chat.completion",
            "model": result["model"],
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": result["content"]},
                "finish_reason": "stop",
            }],
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/v1/kilo/models")
async def kilo_models():
    import httpx
    from app.config import KILO_API_KEY
    key = os.environ.get("KILO_API_KEY", "") or KILO_API_KEY
    if not key:
        return {"error": "KILO_API_KEY not configured"}
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            "https://api.kilo.ai/api/gateway/models",
            headers={"Authorization": f"Bearer {key}"},
        )
    return resp.json() if resp.status_code == 200 else {"error": resp.text[:200]}


# ─── Gemini Proxy ─────────────────────────────────────────────────────────────

@app.post("/v1/gemini/chat/completions")
async def gemini_chat_proxy(request: Request):
    from app.providers import _gemini_chat
    body = await request.json()
    messages = body.get("messages", [])
    model = body.get("model", "gemini-2.5-flash")
    try:
        result = await _gemini_chat(messages, model)
        return {
            "id": "gemini-proxy",
            "object": "chat.completion",
            "model": result["model"],
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": result["content"]},
                "finish_reason": "stop",
            }],
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=HOST, port=PORT, reload=False)
