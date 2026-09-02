import os
import sys
import json
import time
import uuid
import shutil
import asyncio
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional

import uvicorn
import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse, Response, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("production_gateway")

WORKSPACE_BASE = Path(os.getenv("WORKSPACE_BASE", "/tmp/claw_workspaces")).resolve()
WORKSPACE_BASE.mkdir(parents=True, exist_ok=True)
TARGET_BACKEND_URL = os.getenv("TARGET_BACKEND_URL", "https://agent-traveler-dev2.onrender.com").rstrip('/')

app = FastAPI(title="OpenClaw Production Gateway", version="3.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

RUNNING_JOBS: Dict[str, Dict[str, Any]] = {}

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: Optional[bool] = False

class DeploySurgeRequest(BaseModel):
    app_id: str
    domain: Optional[str] = None

@app.get("/health")
async def health_check():
    upstream_healthy = False
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{TARGET_BACKEND_URL}/")
            upstream_healthy = (resp.status_code < 500)
    except Exception as e:
        logger.warning(f"Upstream health check error: {e}")

    return {
        "status": "ok",
        "timestamp": int(time.time()),
        "active_jobs": len(RUNNING_JOBS),
        "upstream_backend": TARGET_BACKEND_URL,
        "upstream_healthy": upstream_healthy,
        "workspace_base": str(WORKSPACE_BASE)
    }

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{
            "id": "claude-opus-4",
            "object": "model",
            "created": 1700000000,
            "owned_by": "openclaw-gateway"
        }]
    }

@app.post("/v1/chat/completions")
async def chat_completions(req: ChatCompletionRequest):
    created_time = int(time.time())
    completion_id = f"chatcmpl-{uuid.uuid4().hex}"
    
    user_prompt = "\n".join([m.content for m in req.messages if m.role == "user"]).strip()
    app_id = f"app-{uuid.uuid4().hex[:8]}"
    app_dir = WORKSPACE_BASE / app_id
    app_dir.mkdir(parents=True, exist_ok=True)

    # Initialize standard Vite/PWA app files in workspace
    (app_dir / "index.html").write_text(f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{app_id}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; padding: 2rem; background: #0f172a; color: #f8fafc; margin: 0; }}
    .container {{ max-width: 800px; margin: 0 auto; background: #1e293b; padding: 2rem; border-radius: 8px; }}
    h1 {{ color: #38bdf8; margin-top: 0; }}
    code {{ background: #0284c7; padding: 0.2rem 0.4rem; border-radius: 4px; }}
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 Generated App: {app_id}</h1>
    <p><strong>Prompt Specification:</strong></p>
    <pre style="background:#0f172a; padding:1rem; border-radius:6px; overflow-x:auto;">{user_prompt}</pre>
  </div>
</body>
</html>""", encoding="utf-8")

    RUNNING_JOBS[app_id] = {
        "status": "ready",
        "created_at": created_time,
        "path": str(app_dir)
    }

    content_resp = (
        f"Build pipeline initiated.\n"
        f"App ID: {app_id}\n"
        f"Workspace Path: {app_dir}"
    )

    return {
        "id": completion_id,
        "object": "chat.completion",
        "created": created_time,
        "model": req.model,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": content_resp}, "finish_reason": "stop"}],
        "usage": {"prompt_tokens": len(user_prompt.split()), "completion_tokens": 15, "total_tokens": len(user_prompt.split()) + 15}
    }

# --- ZIP Export & Download Endpoint ---

@app.get("/api/workspace/{app_id}/download")
async def download_workspace(app_id: str):
    app_dir = WORKSPACE_BASE / app_id
    if not app_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace directory not found")
    
    zip_archive_base = WORKSPACE_BASE / app_id
    zip_file_path = WORKSPACE_BASE / f"{app_id}.zip"
    
    shutil.make_archive(str(zip_archive_base), 'zip', str(app_dir))
    
    return FileResponse(
        path=str(zip_file_path),
        filename=f"{app_id}.zip",
        media_type="application/zip"
    )

# --- Direct Surge Publishing Endpoint ---

@app.post("/api/workspace/deploy-surge")
async def deploy_to_surge(payload: DeploySurgeRequest):
    app_dir = WORKSPACE_BASE / payload.app_id
    if not app_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace directory does not exist")

    target_domain = payload.domain or f"{payload.app_id}-{uuid.uuid4().hex[:4]}.surge.sh"
    
    surge_token = os.getenv("SURGE_TOKEN", "")
    token_arg = f"--token {surge_token}" if surge_token else ""
    surge_cmd = f"npx surge {app_dir} {target_domain} {token_arg}"
    
    proc = await asyncio.create_subprocess_shell(
        surge_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()

    deployment_url = f"https://{target_domain}"
    logger.info(f"Published {payload.app_id} to Surge: {deployment_url}")

    return {
        "status": "success",
        "app_id": payload.app_id,
        "url": deployment_url,
        "domain": target_domain
    }

# --- Reverse Proxy Fallback Handler ---

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
async def reverse_proxy_fallback(request: Request, path: str):
    url = f"{TARGET_BACKEND_URL}/{path}"
    headers = dict(request.headers)
    headers.pop("host", None)
    body = await request.body()
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            upstream_resp = await client.request(
                method=request.method,
                url=url,
                headers=headers,
                params=request.query_params,
                content=body
            )
            return Response(
                content=upstream_resp.content,
                status_code=upstream_resp.status_code,
                headers=dict(upstream_resp.headers)
            )
    except Exception as exc:
        return JSONResponse(
            status_code=502,
            content={"error": {"message": f"Proxy error: {str(exc)}"}}
        )

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3456, log_level="info")
