import logging
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from app.config import HOST, PORT
from app.providers import chat, provider_status

logger = logging.getLogger("traveler.main")

JOBS: dict[str, Any] = {}


def stop_preview(job_id: str) -> None:
    pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup logic
    logger.info("Application startup complete.")
    yield
    # Shutdown logic
    for job_id in list(JOBS):
        try:
            stop_preview(job_id)
        except Exception:
            logger.exception("Failed stopping preview %s", job_id)


app = FastAPI(title="TRAVELER DEV Agent Gateway", lifespan=lifespan)


class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str | None = None
    messages: list[Message]
    temperature: float = 0.2
    max_tokens: int | None = None


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "traveler-dev-agent",
        **provider_status(),
    }


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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=HOST, port=PORT, reload=False)
