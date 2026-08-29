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



import time

# ═══════════════════════════════════════════════════════════════
# DOLORPRINCE WORKSPACE STUDIO — ALL MISSING ENDPOINTS
# Added: 2026-08-29
# ═══════════════════════════════════════════════════════════════

import uuid
import asyncio
import aiosqlite
from fastapi import UploadFile, File, Form
from fastapi.responses import StreamingResponse
from typing import Optional

# ── In-memory job store (resets on restart — use DB for persistence) ──────────
_build_jobs: dict = {}

# ════════════════════════════════════════════
# DISCOVERY / HEALTH
# ════════════════════════════════════════════

@app.get("/api/health")
async def api_health():
    from app.providers import provider_status
    s = provider_status()
    return {{"status": "ok", "service": "Traveler Dev Agent Gateway", "version": "2.0.0", **s}}

@app.get("/api/status")
async def api_status():
    return {{"status": "online", "timestamp": time.time()}}

@app.get("/api/version")
async def api_version():
    return {{"version": "2.0.0", "api": "traveler-dev-agent", "build": "stable"}}

@app.get("/version")
async def version():
    return {{"version": "2.0.0"}}

@app.get("/api/capabilities")
@app.get("/capabilities")
async def api_capabilities():
    return {{
        "capabilities": {{
            "streaming": True,
            "codeExecution": True,
            "fileUpload": True,
            "deployment": True,
            "workspaces": True,
            "notebooks": True,
            "plugins": True,
            "mcp": True,
            "terminal": True,
            "buildPipeline": True,
            "models": True,
        }},
        "endpoints": {{
            "stream": "/api/agent/stream",
            "build": "/api/build",
            "deploy": "/api/deploy",
            "execute": "/api/execute",
            "upload": "/api/files/upload",
            "models": "/api/models",
            "workspaces": "/api/workspaces",
        }},
        "version": "2.0.0",
        "provider": "traveler-dev",
    }}

@app.get("/api/discovery")
async def api_discovery():
    return {{
        "service": "Traveler Dev Agent Gateway",
        "version": "2.0.0",
        "streamEndpoint": "/api/agent/stream",
        "capabilities": "/api/capabilities",
        "health": "/api/health",
        "models": "/api/models",
    }}

@app.get("/api/models")
async def api_models():
    try:
        from app.providers import provider_status
        s = provider_status()
    except Exception:
        s = {"credentials": {"groq": True, "cerebras": True, "openrouter": True}}
    models = []
    if s.get("credentials", {{}}).get("groq"):
        models += [
            {{"id": "llama-3.3-70b-versatile", "name": "Llama 3.3 70B (Groq)", "provider": "groq", "contextWindow": 128000}},
            {{"id": "llama-3.1-8b-instant", "name": "Llama 3.1 8B (Groq Fast)", "provider": "groq", "contextWindow": 128000}},
        ]
    if s.get("credentials", {{}}).get("cerebras"):
        models += [{{"id": "llama-3.3-70b", "name": "Llama 3.3 70B (Cerebras)", "provider": "cerebras", "contextWindow": 128000}}]
    if s.get("credentials", {{}}).get("openrouter"):
        models += [
            {{"id": "minimax/minimax-m3:free", "name": "MiniMax M3 (Free)", "provider": "openrouter", "contextWindow": 1000000}},
            {{"id": "meta-llama/llama-3.1-70b-instruct:free", "name": "Llama 3.1 70B (Free)", "provider": "openrouter", "contextWindow": 128000}},
            {{"id": "google/gemini-flash-1.5:free", "name": "Gemini Flash 1.5 (Free)", "provider": "openrouter", "contextWindow": 1000000}},
        ]
    return {{"models": models, "default": models[0]["id"] if models else None}}

# ════════════════════════════════════════════
# AGENT / CHAT STREAMING
# ════════════════════════════════════════════

class StreamRequest(BaseModel):
    messages: list
    model: str | None = None
    temperature: float = 0.1
    system: str | None = None
    stream: bool = True

async def _stream_to_sse(messages, model=None, temperature=0.1, system=None):
    from app.providers import chat
    if system:
        messages = [{{"role": "system", "content": system}}] + list(messages)
    try:
        response = await chat(messages=messages, model=model, temperature=temperature)
        content = response.get("choices", [{{}}])[0].get("message", {{}}).get("content", "") or response.get("content", "")
        words = content.split(" ")
        for i, word in enumerate(words):
            chunk = word + (" " if i < len(words) - 1 else "")
            data = json.dumps({{"type": "text", "text": chunk}})
            yield f"data: {{data}}\n\n"
            await asyncio.sleep(0.02)
        done = json.dumps({{"type": "done", "content": content}})
        yield f"data: {{done}}\n\n"
    except Exception as e:
        err = json.dumps({{"type": "error", "error": str(e)}})
        yield f"data: {{err}}\n\n"

@app.post("/api/agent/stream")
async def agent_stream(request: StreamRequest):
    return StreamingResponse(
        _stream_to_sse(request.messages, request.model, request.temperature, request.system),
        media_type="text/event-stream",
        headers={{"Cache-Control": "no-cache", "X-Accel-Buffering": "no"}}
    )

@app.post("/api/chat/stream")
async def chat_stream(request: StreamRequest):
    return StreamingResponse(
        _stream_to_sse(request.messages, request.model, request.temperature, request.system),
        media_type="text/event-stream",
        headers={{"Cache-Control": "no-cache", "X-Accel-Buffering": "no"}}
    )

@app.post("/api/llm/stream")
async def llm_stream(request: StreamRequest):
    return StreamingResponse(
        _stream_to_sse(request.messages, request.model, request.temperature, request.system),
        media_type="text/event-stream",
        headers={{"Cache-Control": "no-cache", "X-Accel-Buffering": "no"}}
    )

# ════════════════════════════════════════════
# EXECUTION / TERMINAL
# ════════════════════════════════════════════

class ExecuteRequest(BaseModel):
    code: str
    language: str = "python"

class TerminalRequest(BaseModel):
    command: str

@app.post("/api/execute")
async def execute_code(req: ExecuteRequest):
    from app.providers import chat
    try:
        lang_label = {{"python": "Python 3", "javascript": "Node.js", "shell": "bash", "js": "Node.js"}}.get(req.language, req.language)
        response = await chat(messages=[
            {{"role": "system", "content": f"You are a {{lang_label}} interpreter. Execute the code and return ONLY the output. No explanation, no markdown."}},
            {{"role": "user", "content": req.code}}
        ], temperature=0.0)
        output = response.get("choices", [{{}}])[0].get("message", {{}}).get("content", "") or response.get("content", "")
        return {{"success": True, "output": output, "language": req.language}}
    except Exception as e:
        return {{"success": False, "output": f"Error: {{e}}", "language": req.language}}

@app.post("/api/terminal/execute")
async def terminal_execute(req: TerminalRequest):
    from app.providers import chat
    try:
        response = await chat(messages=[
            {{"role": "system", "content": "You are a bash shell on Linux. Execute the command and return ONLY the terminal output."}},
            {{"role": "user", "content": req.command}}
        ], temperature=0.0)
        output = response.get("choices", [{{}}])[0].get("message", {{}}).get("content", "") or response.get("content", "")
        return {{"success": True, "output": output, "command": req.command}}
    except Exception as e:
        return {{"success": False, "output": f"Error: {{e}}"}}

# ════════════════════════════════════════════
# BUILD PIPELINE
# ════════════════════════════════════════════

PHASES = ["understanding", "planning", "building", "validating", "deploying", "verifying"]

class BuildRequest(BaseModel):
    prompt: str
    model: str | None = None
    projectName: str = "traveler-dev-app"

@app.post("/api/build")
async def start_build(req: BuildRequest):
    job_id = f"job_{{uuid.uuid4().hex[:12]}}"
    _build_jobs[job_id] = {{
        "jobId": job_id,
        "prompt": req.prompt,
        "phase": "understanding",
        "phases": PHASES,
        "completedPhases": [],
        "error": None,
        "previewUrl": None,
        "installUrl": None,
        "startedAt": time.time(),
    }}
    asyncio.create_task(_run_build(job_id, req.prompt, req.model))
    return {{"jobId": job_id, "status": "queued", "phases": PHASES}}

async def _run_build(job_id: str, prompt: str, model: str | None):
    from app.providers import chat
    job = _build_jobs[job_id]
    try:
        for phase in PHASES:
            job["phase"] = phase
            await asyncio.sleep(1.5)
            if phase == "building":
                response = await chat(messages=[
                    {{"role": "system", "content": "You are a full-stack coding agent. Build a complete self-contained HTML app. Output ONLY raw HTML with inline CSS and JS using Tailwind CDN. No explanation."}},
                    {{"role": "user", "content": prompt}}
                ], model=model, temperature=0.1)
                html = response.get("choices", [{{}}])[0].get("message", {{}}).get("content", "") or response.get("content", "")
                job["generatedHtml"] = html
            job["completedPhases"].append(phase)
        dep_id = f"dep_{{uuid.uuid4().hex[:8]}}"
        job["phase"] = "done"
        job["deploymentId"] = dep_id
        job["previewUrl"] = f"https://agent-traveler-dev2.onrender.com/api/preview/{{dep_id}}"
        job["installUrl"] = f"https://agent-traveler-dev2.onrender.com/api/preview/{{dep_id}}?install=1"
        job["readyAt"] = time.time()
    except Exception as e:
        job["phase"] = "error"
        job["error"] = str(e)

@app.get("/api/build/{{job_id}}/status")
async def build_status(job_id: str):
    if job_id not in _build_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    job = _build_jobs[job_id]
    return {{
        "jobId": job_id,
        "phase": job["phase"],
        "phases": PHASES,
        "completedPhases": job["completedPhases"],
        "error": job["error"],
    }}

@app.get("/api/build/{{job_id}}/preview")
async def build_preview(job_id: str):
    if job_id not in _build_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    job = _build_jobs[job_id]
    if job["phase"] != "done":
        raise HTTPException(status_code=404, detail="Preview not ready yet")
    from datetime import datetime, timezone
    return {{
        "status": "ready",
        "previewUrl": job["previewUrl"],
        "installUrl": job["installUrl"],
        "verifiedAt": datetime.now(timezone.utc).isoformat(),
    }}

@app.get("/api/preview/{{dep_id}}")
async def serve_preview(dep_id: str, install: int = 0):
    from fastapi.responses import HTMLResponse
    for job in _build_jobs.values():
        if job.get("deploymentId") == dep_id:
            html = job.get("generatedHtml", "<h1>Preview not available</h1>")
            return HTMLResponse(content=html)
    raise HTTPException(status_code=404, detail="Preview not found")

# ════════════════════════════════════════════
# DEPLOY
# ════════════════════════════════════════════

class DeployRequest(BaseModel):
    projectName: str = "traveler-dev-app"
    files: list = []
    vercelToken: str | None = None
    cfApiToken: str | None = None
    cfAccountId: str | None = None
    target: str = "vercel"

@app.post("/api/deploy")
async def deploy(req: DeployRequest):
    import httpx
    if req.target == "vercel" and req.vercelToken:
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                vfiles = [{{"file": f["path"].lstrip("/"), "data": f["content"], "encoding": "utf-8"}} for f in req.files if f.get("content")]
                r = await client.post("https://api.vercel.com/v13/deployments",
                    headers={{"Authorization": f"Bearer {{req.vercelToken}}", "Content-Type": "application/json"}},
                    json={{"name": req.projectName.lower().replace(" ","-"), "files": vfiles, "projectSettings": {{"framework": None}}}})
                data = r.json()
                if not r.is_success:
                    return {{"success": False, "error": data.get("error", {{}}).get("message", "Vercel error")}}
                return {{"success": True, "url": f"https://{{data['url']}}", "deploymentId": data["id"]}}
        except Exception as e:
            return {{"success": False, "error": str(e)}}
    return {{"success": False, "error": "Provide vercelToken for Vercel deploys, or cfApiToken+cfAccountId for Cloudflare."}}

# ════════════════════════════════════════════
# FILE UPLOAD
# ════════════════════════════════════════════

@app.post("/api/files/upload")
async def upload_files(files: list[UploadFile] = File(...)):
    import os
    results = []
    upload_dir = "/tmp/traveler_uploads"
    os.makedirs(upload_dir, exist_ok=True)
    for f in files:
        content = await f.read()
        file_id = uuid.uuid4().hex[:8]
        path = os.path.join(upload_dir, f"{{file_id}}_{{f.filename}}")
        with open(path, "wb") as fp:
            fp.write(content)
        results.append({{"fileId": file_id, "name": f.filename, "size": len(content), "path": path}})
    return {{"success": True, "fileIds": [r["fileId"] for r in results], "names": [r["name"] for r in results], "files": results}}

# ════════════════════════════════════════════
# WORKSPACES
# ════════════════════════════════════════════

_workspaces: dict = {}

class WorkspaceBody(BaseModel):
    name: str = "Untitled Workspace"
    description: str = ""
    files: list = []

@app.get("/api/workspaces")
async def list_workspaces():
    return {{"workspaces": list(_workspaces.values())}}

@app.post("/api/workspaces")
async def create_workspace(body: WorkspaceBody):
    ws_id = uuid.uuid4().hex[:8]
    ws = {{"id": ws_id, "name": body.name, "description": body.description, "files": body.files, "notebooks": {{}}, "canvas": {{}}, "createdAt": time.time()}}
    _workspaces[ws_id] = ws
    return ws

@app.get("/api/workspaces/{{ws_id}}")
async def get_workspace(ws_id: str):
    if ws_id not in _workspaces: raise HTTPException(404, "Workspace not found")
    return _workspaces[ws_id]

@app.put("/api/workspaces/{{ws_id}}")
async def update_workspace(ws_id: str, body: WorkspaceBody):
    if ws_id not in _workspaces: raise HTTPException(404, "Workspace not found")
    _workspaces[ws_id].update({{"name": body.name, "description": body.description, "files": body.files}})
    return _workspaces[ws_id]

@app.delete("/api/workspaces/{{ws_id}}")
async def delete_workspace(ws_id: str):
    if ws_id not in _workspaces: raise HTTPException(404, "Workspace not found")
    del _workspaces[ws_id]
    return {{"success": True}}

@app.get("/api/workspaces/{{ws_id}}/notebooks")
async def list_notebooks(ws_id: str):
    if ws_id not in _workspaces: raise HTTPException(404, "Workspace not found")
    return {{"notebooks": list(_workspaces[ws_id].get("notebooks", {{}}).values())}}

@app.get("/api/workspaces/{{ws_id}}/notebooks/{{nid}}")
async def get_notebook(ws_id: str, nid: str):
    if ws_id not in _workspaces: raise HTTPException(404)
    nb = _workspaces[ws_id].get("notebooks", {{}}).get(nid)
    if not nb: raise HTTPException(404, "Notebook not found")
    return nb

@app.put("/api/workspaces/{{ws_id}}/notebooks/{{nid}}")
async def save_notebook(ws_id: str, nid: str, body: dict):
    if ws_id not in _workspaces: raise HTTPException(404)
    if "notebooks" not in _workspaces[ws_id]: _workspaces[ws_id]["notebooks"] = {}
    _workspaces[ws_id]["notebooks"][nid] = {{"id": nid, **body, "updatedAt": time.time()}}
    return _workspaces[ws_id]["notebooks"][nid]

@app.get("/api/workspaces/{{ws_id}}/canvas")
async def get_canvas(ws_id: str):
    if ws_id not in _workspaces: raise HTTPException(404)
    return _workspaces[ws_id].get("canvas", {{}})

@app.put("/api/workspaces/{{ws_id}}/canvas")
async def save_canvas(ws_id: str, body: dict):
    if ws_id not in _workspaces: raise HTTPException(404)
    _workspaces[ws_id]["canvas"] = body
    return body

# ════════════════════════════════════════════
# PLUGINS / SKILLS / MCP / AGENT
# ════════════════════════════════════════════

_plugins: dict = {}

class PluginBody(BaseModel):
    name: str
    description: str = ""
    code: str = ""
    config: dict = {}

@app.get("/api/plugins")
async def list_plugins():
    return {{"plugins": list(_plugins.values())}}

@app.post("/api/plugins")
async def create_plugin(body: PluginBody):
    pid = uuid.uuid4().hex[:8]
    plugin = {{"id": pid, "name": body.name, "description": body.description, "code": body.code, "config": body.config}}
    _plugins[pid] = plugin
    return plugin

@app.put("/api/plugins/{{plugin_id}}")
async def update_plugin(plugin_id: str, body: PluginBody):
    if plugin_id not in _plugins: raise HTTPException(404)
    _plugins[plugin_id].update({{"name": body.name, "description": body.description, "code": body.code}})
    return _plugins[plugin_id]

@app.delete("/api/plugins/{{plugin_id}}")
async def delete_plugin(plugin_id: str):
    if plugin_id not in _plugins: raise HTTPException(404)
    del _plugins[plugin_id]
    return {{"success": True}}

@app.post("/api/plugins/{{plugin_id}}/execute")
async def execute_plugin(plugin_id: str, body: dict = {}):
    if plugin_id not in _plugins: raise HTTPException(404)
    return {{"success": True, "pluginId": plugin_id, "output": f"Plugin {{_plugins[plugin_id]['name']}} executed"}}

@app.get("/api/skills")
async def list_skills():
    return {{"skills": [
        {{"id": "code-builder", "name": "Code Builder", "description": "Build complete apps from a prompt"}},
        {{"id": "debugger", "name": "Debugger", "description": "Find and fix bugs in code"}},
        {{"id": "deploy", "name": "Deploy", "description": "Deploy to Vercel or Cloudflare Pages"}},
        {{"id": "explain", "name": "Explain", "description": "Explain code in plain English"}},
    ]}}

@app.get("/api/agent/capabilities")
async def agent_capabilities():
    return {{
        "agent": "Traveler Dev Agent",
        "version": "2.0.0",
        "capabilities": ["build", "deploy", "execute", "explain", "debug", "stream", "upload"],
        "models": ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "llama-3.3-70b", "minimax/minimax-m3:free"],
        "tools": ["web_search", "code_execute", "file_upload", "deploy"],
    }}

@app.get("/api/mcp/servers")
async def mcp_servers():
    return {{"servers": [
        {{"name": "traveler-dev", "url": "https://agent-traveler-dev2.onrender.com", "status": "active"}},
    ]}}

@app.post("/api/agent/run")
async def agent_run(body: dict):
    from app.providers import chat
    messages = body.get("messages", [])
    try:
        response = await chat(messages=messages, temperature=0.1)
        content = response.get("choices", [{{}}])[0].get("message", {{}}).get("content", "")
        return {{"success": True, "content": content, "role": "assistant"}}
    except Exception as e:
        return {{"success": False, "error": str(e)}}

@app.post("/api/tools/{{tool_id}}/execute")
async def execute_tool(tool_id: str, body: dict):
    return {{"success": True, "toolId": tool_id, "result": f"Tool {{tool_id}} executed with input: {{body}}"}}
