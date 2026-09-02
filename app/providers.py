"""
providers.py
Local:  routes through proxy-server.js on localhost:3456
HF Space: uses GROQ_API_KEY directly (no proxy needed)
"""
import os, logging, httpx

logger = logging.getLogger("traveler.providers")

GROQ_API_KEY       = os.environ.get("GROQ_API_KEY", "").strip()
OPENAI_BASE_URL    = os.environ.get("OPENAI_BASE_URL", "http://localhost:3456/v1").rstrip("/")
OPENAI_API_KEY     = os.environ.get("OPENAI_API_KEY", "not-needed")
DEFAULT_MODEL      = "llama3-70b-8192"

logger.info(f"[providers] base={OPENAI_BASE_URL} groq={'SET' if GROQ_API_KEY else 'MISSING'}")


async def chat(messages, model=None, temperature=0.1, max_tokens=4096):
    # On HF Space: call Groq directly
    if GROQ_API_KEY:
        url = "https://api.groq.com/openai/v1/chat/completions"
        key = GROQ_API_KEY
    else:
        # Local: go through proxy
        url = f"{OPENAI_BASE_URL}/chat/completions"
        key = OPENAI_API_KEY

    payload = {
        "model":       DEFAULT_MODEL,
        "messages":    messages,
        "temperature": temperature,
        "max_tokens":  max_tokens or 4096,
    }
    logger.info(f"[chat] POST {url} model={DEFAULT_MODEL}")

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            url,
            json=payload,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type":  "application/json",
            },
        )
        resp.raise_for_status()
        return resp.json()


def provider_status():
    return {
        "primary":     "groq",
        "model":       DEFAULT_MODEL,
        "credentials": {"groq": bool(GROQ_API_KEY)},
        "base_url":    OPENAI_BASE_URL,
    }

WEBCONTAINER_API_URL = ""
async def webcontainer_boot(files): return {"status": "error"}
async def webcontainer_run_command(i, c, a=None): return {"status": "error"}
def webcontainer_status(): return {"enabled": False}
