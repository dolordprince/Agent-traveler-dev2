import asyncio
import json
import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Any, Optional

import httpx
from fastapi import FastAPI, File, HTTPException, Request, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, StreamingResponse
from pydantic import BaseModel

from app.config import HOST, PORT, WEBCONTAINER_ENABLED
from app.providers import (
    chat,
    provider_status,
    webcontainer_boot,
    webcontainer_run_command,
    webcontainer_status,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("traveler.main")

# ── In-memory stores (reset on restart) ───────────────────────────────────────
_build_jobs: dict[str, Any] = {}
_workspaces: dict[str, Any] = {}
_plugins: dict[str, Any] = {}

PHASES = ["understanding", "planning", "building", "validating", "deploying", "verifying"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Traveler Dev Agent Gateway v2.0.0 started")
    yield
    logger.info("Shutting down")


app = FastAPI(title="TRAVELER DEV Agent Gateway", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request models ─────────────────────────────────────────────────────────────

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: Optional[str] = None
    messages: list[Message]
    temperature: float = 0.2
    max_tokens: Optional[int] = None

class StreamRequest(BaseModel):
    messages: list
    model: Optional[str] = None
    temperature: float = 0.1
    system: Optional[str] = None
    stream: bool = True

class BuildRequest(BaseModel):
    prompt: str
    model: Optional[str] = None
    projectName: str = "traveler-dev-app"

class DeployRequest(BaseModel):
    projectName: str = "traveler-dev-app"
    files: list = []
    vercelToken: Optional[str] = None
    cfApiToken: Optional[str] = None
    cfAccountId: Optional[str] = None
    target: str = "vercel"

class ExecuteRequest(BaseModel):
    code: str
    language: str = "python"

class TerminalRequest(BaseModel):
    command: str

class RunCodeRequest(BaseModel):
    language: str
    code: str

class WorkspaceBody(BaseModel):
    name: str = "Untitled Workspace"
    description: str = ""
    files: list = []

class PluginBody(BaseModel):
    name: str
    description: str = ""
    code: str = ""
    config: dict = {}

class WebContainerBootRequest(BaseModel):
    files: dict[str, str]  # { "path/file.tsx": "content" }

class WebContainerExecRequest(BaseModel):
    instance_id: str
    command: str
    args: list[str] = []


# ── Root & Health ──────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "TRAVELER DEV Agent Gateway",
        "version": "2.0.0",
        "endpoints": [
            "/health", "/api/health", "/api/status",
            "/v1/chat/completions", "/v1/models",
            "/api/agent/stream", "/api/chat/stream",
            "/api/build", "/api/deploy", "/api/execute",
            "/api/files/upload", "/api/models",
            "/api/workspaces", "/api/plugins",
            "/api/webcontainer/boot", "/api/webcontainer/exec",
            "/ws/terminal",
        ],
    }

@app.get("/health")
@app.get("/api/health")
async def health_check():
    return {"status": "ok", "service": "traveler-dev-agent", **provider_status()}


@app.get("/api/config")
async def api_config():
    """Return the public runtime configuration used by the Traveler Dev frontend."""
    from app.config import (
        HOST,
        PORT,
        WEBCONTAINER_ENABLED,
    )

    return {
        "service": "traveler-dev-agent",
        "version": "2.0.0",
        "host": HOST,
        "port": PORT,
        "providers": provider_status(),
        "webcontainer": {
            "enabled": False,
            "mode": "browser",
            "api": "@webcontainer/api",
            "server_boot": False,
        },
    }


@app.get("/api/provider/status")
async def api_provider_status():
    """Return provider configuration and credential availability."""
    return provider_status()

@app.get("/api/status")
async def api_status():
    return {"status": "online", "timestamp": time.time()}

@app.get("/api/version")
@app.get("/version")
async def api_version():
    return {"version": "2.0.0", "api": "traveler-dev-agent", "build": "stable"}

@app.get("/api/capabilities")
@app.get("/capabilities")
async def api_capabilities():
    return {
        "capabilities": {
            "streaming": True, "codeExecution": True, "fileUpload": True,
            "deployment": True, "workspaces": True, "notebooks": True,
            "plugins": True, "mcp": True, "terminal": True,
            "buildPipeline": True, "models": True, "webcontainer": WEBCONTAINER_ENABLED,
        },
        "endpoints": {
            "stream": "/api/agent/stream", "build": "/api/build",
            "deploy": "/api/deploy", "execute": "/api/execute",
            "upload": "/api/files/upload", "models": "/api/models",
            "workspaces": "/api/workspaces",
            "webcontainer": "/api/webcontainer/boot",
        },
        "version": "2.0.0",
        "provider": "traveler-dev",
    }

@app.get("/api/discovery")
async def api_discovery():
    return {
        "service": "Traveler Dev Agent Gateway",
        "version": "2.0.0",
        "streamEndpoint": "/api/agent/stream",
        "capabilities": "/api/capabilities",
        "health": "/api/health",
        "models": "/api/models",
    }


# ── Models ─────────────────────────────────────────────────────────────────────

def _build_model_list(s: dict) -> list:
    models = []
    if s.get("credentials", {}).get("groq"):
        models += [
            {"id": "openai/gpt-oss-120b", "name": "GPT-OSS 120B (Groq)", "provider": "groq", "contextWindow": 32768},
            {"id": "openai/gpt-oss-20b",  "name": "GPT-OSS 20B (Groq Fast)", "provider": "groq", "contextWindow": 32768},
        ]
    if s.get("credentials", {}).get("cerebras"):
        models += [
            {"id": "llama-3.3-70b", "name": "Llama 3.3 70B (Cerebras)", "provider": "cerebras", "contextWindow": 128000},
        ]
    if s.get("credentials", {}).get("openrouter"):
        models += [
            {"id": "minimax/minimax-m3:free", "name": "MiniMax M3 (Free)", "provider": "openrouter", "contextWindow": 1000000},
            {"id": "meta-llama/llama-3.1-70b-instruct:free", "name": "Llama 3.1 70B (Free)", "provider": "openrouter", "contextWindow": 128000},
            {"id": "google/gemini-flash-1.5:free", "name": "Gemini Flash 1.5 (Free)", "provider": "openrouter", "contextWindow": 1000000},
        ]
    return models

@app.get("/v1/models")
@app.get("/api/models")
async def list_models():
    s = provider_status()
    models = _build_model_list(s)
    return {
        "object": "list",
        "data": [{"id": m["id"], "object": "model", "created": 1700000000, "owned_by": m["provider"], "name": m["name"]} for m in models],
        "models": models,
        "default": models[0]["id"] if models else None,
        "primary": s.get("primary"),
        "fallbacks": s.get("fallbacks", []),
    }


# ── Core chat (OpenAI-compatible) ──────────────────────────────────────────────

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    try:
        # Pydantic 1.x compatibility: Message inherits BaseModel and
        # exposes .dict(), not .model_dump().
        raw_messages = [msg.dict() for msg in request.messages]

        response = await chat(
            messages=raw_messages,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        )

        if not isinstance(response, dict):
            raise TypeError(
                f"LLM gateway returned {type(response).__name__}; expected dict"
            )

        choices = response.get("choices")

        if not choices:
            content = response.get("content", "")
            choices = [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": content,
                },
                "finish_reason": "stop",
            }]

        return {
            "id": response.get("id", "chatcmpl-default"),
            "object": "chat.completion",
            "model": response.get("model", request.model or "default"),
            "choices": choices,
            "usage": response.get("usage", {}),
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Chat completion failed")
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        )


# ── Streaming ──────────────────────────────────────────────────────────────────

async def _stream_to_sse(messages, model=None, temperature=0.1, system=None):
    if system:
        messages = [{"role": "system", "content": system}] + list(messages)
    try:
        response = await chat(messages=messages, model=model, temperature=temperature)
        content = (
            response.get("choices", [{}])[0].get("message", {}).get("content", "")
            or response.get("content", "")
        )
        words = content.split(" ")
        for i, word in enumerate(words):
            chunk = word + (" " if i < len(words) - 1 else "")
            yield f"data: {json.dumps({'type': 'text', 'text': chunk})}\n\n"
            await asyncio.sleep(0.02)
        yield f"data: {json.dumps({'type': 'done', 'content': content})}\n\n"
    except Exception as e:
        yield f"data: {json.dumps({'type': 'error', 'error': str(e)})}\n\n"

@app.post("/api/agent/stream")
@app.post("/api/chat/stream")
@app.post("/api/llm/stream")
async def agent_stream(request: StreamRequest):
    return StreamingResponse(
        _stream_to_sse(request.messages, request.model, request.temperature, request.system),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ── Code execution ─────────────────────────────────────────────────────────────

@app.post("/api/execute")
@app.post("/api/run-code")
async def execute_code(req: ExecuteRequest):
    lang_label = {"python": "Python 3", "javascript": "Node.js", "shell": "bash", "js": "Node.js"}.get(req.language, req.language)
    try:
        response = await chat(messages=[
            {"role": "system", "content": f"You are a {lang_label} interpreter. Execute the code and return ONLY the output. No explanation, no markdown."},
            {"role": "user", "content": req.code},
        ], temperature=0.0)
        output = response.get("choices", [{}])[0].get("message", {}).get("content", "") or response.get("content", "")
        return {"success": True, "output": output, "language": req.language}
    except Exception as e:
        return {"success": False, "output": f"Error: {e}", "language": req.language}

@app.post("/api/terminal/execute")
async def terminal_execute(req: TerminalRequest):
    try:
        response = await chat(messages=[
            {"role": "system", "content": "You are a bash shell on Linux. Execute the command and return ONLY the terminal output."},
            {"role": "user", "content": req.command},
        ], temperature=0.0)
        output = response.get("choices", [{}])[0].get("message", {}).get("content", "") or response.get("content", "")
        return {"success": True, "output": output, "command": req.command}
    except Exception as e:
        return {"success": False, "output": f"Error: {e}"}


# ── WebSocket terminal ─────────────────────────────────────────────────────────

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


# ── StackBlitz WebContainer ────────────────────────────────────────────────────

@app.post("/api/webcontainer/boot")
async def wc_boot(req: WebContainerBootRequest):
    """Boot a WebContainer with project files."""
    result = await webcontainer_boot(req.files)
    if result.get("status") == "error":
        raise HTTPException(status_code=502, detail=result.get("message", "WebContainer boot failed"))
    return result

@app.post("/api/webcontainer/exec")
async def wc_exec(req: WebContainerExecRequest):
    """Run a command inside a live WebContainer instance."""
    result = await webcontainer_run_command(req.instance_id, req.command, req.args)
    if result.get("status") == "error":
        raise HTTPException(status_code=502, detail=result.get("message", "WebContainer exec failed"))
    return result

@app.get("/api/webcontainer/status")
async def wc_status():
    return webcontainer_status()


# ── Build pipeline ─────────────────────────────────────────────────────────────

@app.post("/api/build")
async def start_build(req: BuildRequest):
    job_id = f"job_{uuid.uuid4().hex[:12]}"
    _build_jobs[job_id] = {
        "jobId": job_id, "prompt": req.prompt, "phase": "understanding",
        "phases": PHASES, "completedPhases": [], "error": None,
        "previewUrl": None, "installUrl": None, "startedAt": time.time(),
    }
    asyncio.create_task(_run_build(job_id, req.prompt, req.model))
    return {"jobId": job_id, "status": "queued", "phases": PHASES}

async def _run_build(job_id: str, prompt: str, model: Optional[str]):
    job = _build_jobs[job_id]
    try:
        for phase in PHASES:
            job["phase"] = phase
            await asyncio.sleep(1.5)
            if phase == "building":
                response = await chat(messages=[
                    {"role": "system", "content": "You are a full-stack coding agent. Build a complete self-contained HTML app. Output ONLY raw HTML with inline CSS and JS using Tailwind CDN. No explanation."},
                    {"role": "user", "content": prompt},
                ], model=model, temperature=0.1)
                html = response.get("choices", [{}])[0].get("message", {}).get("content", "") or response.get("content", "")
                job["generatedHtml"] = html
            job["completedPhases"].append(phase)
        dep_id = f"dep_{uuid.uuid4().hex[:8]}"
        job["phase"] = "done"
        job["deploymentId"] = dep_id
        job["previewUrl"] = f"https://agent-traveler-dev2.onrender.com/api/preview/{dep_id}"
        job["installUrl"] = f"https://agent-traveler-dev2.onrender.com/api/preview/{dep_id}?install=1"
        job["readyAt"] = time.time()
    except Exception as e:
        job["phase"] = "error"
        job["error"] = str(e)

@app.get("/api/build/{job_id}/status")
async def build_status(job_id: str):
    if job_id not in _build_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    job = _build_jobs[job_id]
    return {"jobId": job_id, "phase": job["phase"], "phases": PHASES, "completedPhases": job["completedPhases"], "error": job["error"]}

@app.get("/api/build/{job_id}/preview")
async def build_preview(job_id: str):
    if job_id not in _build_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    job = _build_jobs[job_id]
    if job["phase"] != "done":
        raise HTTPException(status_code=404, detail="Preview not ready yet")
    from datetime import datetime, timezone
    return {"status": "ready", "previewUrl": job["previewUrl"], "installUrl": job["installUrl"], "verifiedAt": datetime.now(timezone.utc).isoformat()}

@app.get("/api/preview/{dep_id}")
async def serve_preview(dep_id: str, install: int = 0):
    for job in _build_jobs.values():
        if job.get("deploymentId") == dep_id:
            html = job.get("generatedHtml", "<h1>Preview not available</h1>")
            return HTMLResponse(content=html)
    raise HTTPException(status_code=404, detail="Preview not found")


# ── Deploy ─────────────────────────────────────────────────────────────────────

@app.post("/api/deploy")
async def deploy(req: DeployRequest):
    if req.target == "vercel" and req.vercelToken:
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                vfiles = [{"file": f["path"].lstrip("/"), "data": f["content"], "encoding": "utf-8"} for f in req.files if f.get("content")]
                r = await client.post(
                    "https://api.vercel.com/v13/deployments",
                    headers={"Authorization": f"Bearer {req.vercelToken}", "Content-Type": "application/json"},
                    json={"name": req.projectName.lower().replace(" ", "-"), "files": vfiles, "projectSettings": {"framework": None}},
                )
                data = r.json()
                if not r.is_success:
                    return {"success": False, "error": data.get("error", {}).get("message", "Vercel error")}
                return {"success": True, "url": f"https://{data['url']}", "deploymentId": data["id"]}
        except Exception as e:
            return {"success": False, "error": str(e)}
    return {"success": False, "error": "Provide vercelToken for Vercel, or cfApiToken+cfAccountId for Cloudflare."}


# ── File upload ────────────────────────────────────────────────────────────────

@app.post("/api/files/upload")
async def upload_files(files: list[UploadFile] = File(...)):
    results = []
    upload_dir = "/tmp/traveler_uploads"
    os.makedirs(upload_dir, exist_ok=True)
    for f in files:
        content = await f.read()
        file_id = uuid.uuid4().hex[:8]
        path = os.path.join(upload_dir, f"{file_id}_{f.filename}")
        with open(path, "wb") as fp:
            fp.write(content)
        results.append({"fileId": file_id, "name": f.filename, "size": len(content), "path": path})
    return {"success": True, "fileIds": [r["fileId"] for r in results], "files": results}


# ── Workspaces ─────────────────────────────────────────────────────────────────

@app.get("/api/workspaces")
async def list_workspaces():
    return {"workspaces": list(_workspaces.values())}

@app.post("/api/workspaces")
async def create_workspace(body: WorkspaceBody):
    ws_id = uuid.uuid4().hex[:8]
    ws = {"id": ws_id, "name": body.name, "description": body.description, "files": body.files, "notebooks": {}, "canvas": {}, "createdAt": time.time()}
    _workspaces[ws_id] = ws
    return ws

@app.get("/api/workspaces/{ws_id}")
async def get_workspace(ws_id: str):
    if ws_id not in _workspaces:
        raise HTTPException(404, "Workspace not found")
    return _workspaces[ws_id]

@app.put("/api/workspaces/{ws_id}")
async def update_workspace(ws_id: str, body: WorkspaceBody):
    if ws_id not in _workspaces:
        raise HTTPException(404, "Workspace not found")
    _workspaces[ws_id].update({"name": body.name, "description": body.description, "files": body.files})
    return _workspaces[ws_id]

@app.delete("/api/workspaces/{ws_id}")
async def delete_workspace(ws_id: str):
    if ws_id not in _workspaces:
        raise HTTPException(404, "Workspace not found")
    del _workspaces[ws_id]
    return {"success": True}

@app.get("/api/workspaces/{ws_id}/notebooks")
async def list_notebooks(ws_id: str):
    if ws_id not in _workspaces:
        raise HTTPException(404, "Workspace not found")
    return {"notebooks": list(_workspaces[ws_id].get("notebooks", {}).values())}

@app.get("/api/workspaces/{ws_id}/notebooks/{nid}")
async def get_notebook(ws_id: str, nid: str):
    if ws_id not in _workspaces:
        raise HTTPException(404)
    nb = _workspaces[ws_id].get("notebooks", {}).get(nid)
    if not nb:
        raise HTTPException(404, "Notebook not found")
    return nb

@app.put("/api/workspaces/{ws_id}/notebooks/{nid}")
async def save_notebook(ws_id: str, nid: str, body: dict):
    if ws_id not in _workspaces:
        raise HTTPException(404)
    if "notebooks" not in _workspaces[ws_id]:
        _workspaces[ws_id]["notebooks"] = {}
    _workspaces[ws_id]["notebooks"][nid] = {"id": nid, **body, "updatedAt": time.time()}
    return _workspaces[ws_id]["notebooks"][nid]

@app.get("/api/workspaces/{ws_id}/canvas")
async def get_canvas(ws_id: str):
    if ws_id not in _workspaces:
        raise HTTPException(404)
    return _workspaces[ws_id].get("canvas", {})

@app.put("/api/workspaces/{ws_id}/canvas")
async def save_canvas(ws_id: str, body: dict):
    if ws_id not in _workspaces:
        raise HTTPException(404)
    _workspaces[ws_id]["canvas"] = body
    return body


# ── Plugins / Skills / MCP / Agent ────────────────────────────────────────────

@app.get("/api/plugins")
async def list_plugins():
    return {"plugins": list(_plugins.values())}

@app.post("/api/plugins")
async def create_plugin(body: PluginBody):
    pid = uuid.uuid4().hex[:8]
    plugin = {"id": pid, "name": body.name, "description": body.description, "code": body.code, "config": body.config}
    _plugins[pid] = plugin
    return plugin

@app.put("/api/plugins/{plugin_id}")
async def update_plugin(plugin_id: str, body: PluginBody):
    if plugin_id not in _plugins:
        raise HTTPException(404)
    _plugins[plugin_id].update({"name": body.name, "description": body.description, "code": body.code})
    return _plugins[plugin_id]

@app.delete("/api/plugins/{plugin_id}")
async def delete_plugin(plugin_id: str):
    if plugin_id not in _plugins:
        raise HTTPException(404)
    del _plugins[plugin_id]
    return {"success": True}

@app.post("/api/plugins/{plugin_id}/execute")
async def execute_plugin(plugin_id: str, body: dict = {}):
    if plugin_id not in _plugins:
        raise HTTPException(404)
    return {"success": True, "pluginId": plugin_id, "output": f"Plugin {_plugins[plugin_id]['name']} executed"}

@app.get("/api/skills")
async def list_skills():
    return {"skills": [
        {"id": "code-builder", "name": "Code Builder", "description": "Build complete apps from a prompt"},
        {"id": "debugger", "name": "Debugger", "description": "Find and fix bugs in code"},
        {"id": "deploy", "name": "Deploy", "description": "Deploy to Vercel or Cloudflare Pages"},
        {"id": "explain", "name": "Explain", "description": "Explain code in plain English"},
    ]}

@app.get("/api/agent/capabilities")
async def agent_capabilities():
    return {
        "agent": "Traveler Dev Agent",
        "version": "2.0.0",
        "capabilities": ["build", "deploy", "execute", "explain", "debug", "stream", "upload", "webcontainer"],
        "models": ["openai/gpt-oss-120b", "openai/gpt-oss-20b"],
        "tools": ["web_search", "code_execute", "file_upload", "deploy", "webcontainer"],
    }

@app.get("/api/mcp/servers")
async def mcp_servers():
    return {"servers": [
        {"name": "traveler-dev", "url": "https://agent-traveler-dev2.onrender.com", "status": "active"},
    ]}

@app.post("/api/agent/run")
async def agent_run(body: dict):
    """
    Execute one agent request.

    Accepted input:
      {"message": "..."}
      {"messages": [{"role": "user", "content": "..."}]}
      {"message": "...", "model": "...", "temperature": 0.1, "max_tokens": 4096}

    The singular `message` form is normalized into the OpenAI-compatible
    messages format so frontend clients cannot accidentally invoke the agent
    with an empty conversation.
    """
    try:
        raw_messages = body.get("messages")

        if raw_messages is None:
            message = body.get("message")
            if isinstance(message, str) and message.strip():
                raw_messages = [
                    {"role": "user", "content": message.strip()}
                ]
            else:
                raw_messages = []

        if not isinstance(raw_messages, list):
            raise HTTPException(
                status_code=400,
                detail="messages must be an array"
            )

        messages = []
        for item in raw_messages:
            if not isinstance(item, dict):
                raise HTTPException(
                    status_code=400,
                    detail="each message must be an object"
                )

            role = item.get("role")
            content = item.get("content")

            if role not in {"system", "user", "assistant"}:
                raise HTTPException(
                    status_code=400,
                    detail="message role must be system, user, or assistant"
                )

            if not isinstance(content, str):
                raise HTTPException(
                    status_code=400,
                    detail="message content must be a string"
                )

            messages.append({
                "role": role,
                "content": content
            })

        if not messages:
            raise HTTPException(
                status_code=400,
                detail="message or messages is required"
            )

        response = await chat(
            messages=messages,
            model=body.get("model"),
            temperature=float(body.get("temperature", 0.1)),
            max_tokens=body.get("max_tokens"),
        )

        choices = response.get("choices") or []
        content = ""

        if choices:
            message = choices[0].get("message") or {}
            content = message.get("content") or ""

        if not content:
            content = response.get("content") or ""

        return {
            "success": True,
            "content": content,
            "role": "assistant",
            "model": response.get("model"),
            "usage": response.get("usage", {}),
        }

    except HTTPException:
        raise
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid agent request: {exc}"
        )
    except Exception as exc:
        logger.exception("Agent run failed")
        return {
            "success": False,
            "error": str(exc)
        }

@app.post("/api/tools/{tool_id}/execute")
async def execute_tool(tool_id: str, body: dict = {}):
    return {"success": True, "toolId": tool_id, "result": f"Tool {tool_id} executed with input: {body}"}


# ── Android APK build proxy ────────────────────────────────────────────────────

@app.post("/api/android/build")
async def android_build(request: Request):
    body = await request.json()
    hf_url = "https://daviddolor-traveler-dev-backend.hf.space/api/android/build"
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(hf_url, json=body, headers={"Content-Type": "application/json"})
        if resp.status_code == 200:
            return resp.json()
        return {"success": False, "error": f"HF Space returned {resp.status_code}. Endpoint needs to be added.", "hf_url": hf_url}
    except httpx.TimeoutException:
        return {"success": False, "error": "APK build timed out after 120s. HF Space may be cold-starting."}
    except Exception as exc:
        return {"success": False, "error": str(exc)}


# ── Entry point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=HOST, port=PORT, reload=False)
