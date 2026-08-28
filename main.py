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


# ─── WebSocket Terminal ────────────────────────────────────────────────────────

import asyncio
from fastapi import WebSocket, WebSocketDisconnect

@app.websocket("/ws/terminal")
async def terminal_ws(websocket: WebSocket):
    await websocket.accept()
    try:
        process = await asyncio.create_subprocess_shell(
            "/bin/bash",
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )

        async def send_output():
            try:
                while True:
                    data = await process.stdout.read(1024)
                    if not data:
                        break
                    await websocket.send_text(data.decode(errors="replace"))
            except Exception:
                pass

        async def recv_input():
            try:
                while True:
                    cmd = await websocket.receive_text()
                    if process.stdin:
                        process.stdin.write(cmd.encode())
                        await process.stdin.drain()
            except WebSocketDisconnect:
                pass

        await asyncio.gather(send_output(), recv_input())
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.exception("Terminal WS error: %s", exc)
    finally:
        try:
            await websocket.close()
        except Exception:
            pass


# ─── Models list ──────────────────────────────────────────────────────────────

@app.get("/v1/models")
async def list_models():
    """Return available models from all active providers."""
    from app.providers import provider_status
    status = provider_status()
    models = []

    if status.get("credentials", {}).get("groq"):
        models += [
            {"id": "llama-3.3-70b-versatile", "provider": "groq", "name": "Llama 3.3 70B (Groq)"},
            {"id": "llama-3.1-8b-instant", "provider": "groq", "name": "Llama 3.1 8B (Groq Fast)"},
        ]
    if status.get("credentials", {}).get("cerebras"):
        models += [
            {"id": "llama-3.3-70b", "provider": "cerebras", "name": "Llama 3.3 70B (Cerebras)"},
        ]
    if status.get("credentials", {}).get("openrouter"):
        models += [
            {"id": "minimax/minimax-m3:free", "provider": "openrouter", "name": "MiniMax M3 (Free)"},
            {"id": "meta-llama/llama-3.1-70b-instruct:free", "provider": "openrouter", "name": "Llama 3.1 70B (Free)"},
            {"id": "google/gemini-flash-1.5:free", "provider": "openrouter", "name": "Gemini Flash 1.5 (Free)"},
        ]

    return {
        "object": "list",
        "data": [
            {
                "id": m["id"],
                "object": "model",
                "created": 1700000000,
                "owned_by": m["provider"],
                "name": m["name"],
            }
            for m in models
        ],
        "primary": status.get("primary"),
        "fallbacks": status.get("fallbacks", []),
    }


# ─── Android APK build proxy ──────────────────────────────────────────────────

@app.post("/api/android/build")
async def android_build(request: Request):
    """Proxy APK build request to HF Space builder."""
    import httpx
    body = await request.json()
    hf_url = "https://daviddolor-traveler-dev-backend.hf.space/api/android/build"

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                hf_url,
                json=body,
                headers={"Content-Type": "application/json"},
            )
        if resp.status_code == 200:
            return resp.json()
        # HF Space endpoint doesn't exist yet — return helpful error
        return {
            "success": False,
            "error": f"HF Space builder returned {resp.status_code}. The /api/android/build endpoint needs to be added to daviddolor-traveler-dev-backend.",
            "hf_url": hf_url,
        }
    except httpx.TimeoutException:
        return {"success": False, "error": "APK build timed out after 120s. HF Space may be cold-starting."}
    except Exception as exc:
        return {"success": False, "error": str(exc)}


# ─── Code execution (for Notebook cells) ─────────────────────────────────────

class RunCodeRequest(BaseModel):
    language: str
    code: str

@app.post("/api/run-code")
async def run_code(req: RunCodeRequest):
    """Execute code via AI for notebook cells."""
    lang_map = {
        "javascript": "Node.js JavaScript",
        "python": "Python 3.11",
        "shell": "bash shell",
    }
    lang_label = lang_map.get(req.language, req.language)

    try:
        raw_messages = [
            {
                "role": "system",
                "content": f"You are a {lang_label} interpreter. Execute the code and return ONLY the output — no explanation, no markdown, no code fences. Just the raw output as it would appear in a terminal."
            },
            {"role": "user", "content": req.code}
        ]
        from app.providers import chat
        response = await chat(messages=raw_messages, temperature=0.0)
        content = response.get("choices", [{}])[0].get("message", {}).get("content", "") or response.get("content", "")
        return {"success": True, "output": content}
    except Exception as exc:
        return {"success": False, "output": f"Execution error: {exc}"}

