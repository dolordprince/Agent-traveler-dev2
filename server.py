import os
import sys
import json
import time
import uuid
import asyncio
import logging
from pathlib import Path
from typing import AsyncGenerator, Dict, Any, List, Optional

import uvicorn
import httpx
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks, status
from fastapi.responses import JSONResponse, StreamingResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Production Logging Configuration
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("proxy_gateway")

# Environment Configurations
WORKSPACE_BASE = Path(os.getenv("WORKSPACE_BASE", "/tmp/claw_workspaces")).resolve()
WORKSPACE_BASE.mkdir(parents=True, exist_ok=True)

TARGET_BACKEND_URL = os.getenv("TARGET_BACKEND_URL", "https://agent-traveler-dev2.onrender.com").rstrip('/')
PORT = 3456
MODEL_ALIAS = "claude-opus-4"

app = FastAPI(title="OpenClaw Reverse Proxy Gateway", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

RUNNING_JOBS: Dict[str, Dict[str, Any]] = {}

# --- Global Catch-All Exception Handler ---

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled Error on {request.method} {request.url.path}: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": f"Proxy Gateway Error: {str(exc)}",
                "type": "proxy_error",
                "code": 500
            }
        }
    )

# --- Request / Response Models ---

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: Optional[bool] = False
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 1.0

# --- Core Pipeline Execution (Writes Local Build State) ---

async def run_pipeline(app_id: str, app_dir: Path, prd_content: str):
    """
    Executes skill build locally and logs outputs/errors to workspace files.
    """
    logger.info(f"Executing pipeline build for {app_id} in {app_dir}")
    
    # Write PRD document to workspace
    prd_path = app_dir / "prd.md"
    prd_path.write_text(prd_content, encoding="utf-8")
    
    skill_cmd = f"npx --yes skills run @zai-org/glmv-prd-to-app --dir {app_dir}"
    
    RUNNING_JOBS[app_id]["status"] = "building"
    RUNNING_JOBS[app_id]["step"] = "executing_skill"

    try:
        proc = await asyncio.create_subprocess_shell(
            skill_cmd,
            cwd=str(app_dir),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await proc.communicate()
        
        # Write execution logs to local workspace
        (app_dir / "build_stdout.log").write_bytes(stdout)
        (app_dir / "build_stderr.log").write_bytes(stderr)
        
        if proc.returncode != 0:
            err_msg = stderr.decode('utf-8', errors='replace')
            logger.error(f"Build failed for {app_id}: {err_msg}")
            RUNNING_JOBS[app_id]["status"] = "failed"
            RUNNING_JOBS[app_id]["error"] = err_msg
            return

        # Execute deployment script if available
        start_script = app_dir / "start.sh"
        if start_script.exists():
            start_script.chmod(0o755)
            RUNNING_JOBS[app_id]["step"] = "starting_services"
            
            start_proc = await asyncio.create_subprocess_exec(
                "bash", str(start_script),
                cwd=str(app_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            RUNNING_JOBS[app_id]["pid"] = start_proc.pid
            RUNNING_JOBS[app_id]["status"] = "running"
            logger.info(f"App {app_id} started successfully with PID {start_proc.pid}")
        else:
            RUNNING_JOBS[app_id]["status"] = "completed_without_start_script"
            logger.warning(f"No start.sh script generated in {app_dir}")

    except Exception as e:
        logger.error(f"Pipeline execution error for {app_id}: {str(e)}", exc_info=True)
        RUNNING_JOBS[app_id]["status"] = "error"
        RUNNING_JOBS[app_id]["error"] = str(e)
        (app_dir / "pipeline_error.log").write_text(str(e), encoding="utf-8")

# --- Native Gateway Routes ---

@app.get("/health")
async def health_check():
    # Ping downstream server to verify connectivity
    upstream_healthy = False
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{TARGET_BACKEND_URL}/")
            upstream_healthy = (resp.status_code < 500)
    except Exception as e:
        logger.warning(f"Upstream health check failed: {e}")

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
        "data": [
            {
                "id": MODEL_ALIAS,
                "object": "model",
                "created": 1700000000,
                "owned_by": "openclaw-gateway",
                "permission": [],
                "root": MODEL_ALIAS,
                "parent": None
            }
        ]
    }

@app.post("/v1/chat/completions")
async def chat_completions(req: ChatCompletionRequest, background_tasks: BackgroundTasks):
    try:
        created_time = int(time.time())
        completion_id = f"chatcmpl-{uuid.uuid4().hex}"
        
        user_prompt = ""
        for msg in req.messages:
            if msg.role == "user":
                user_prompt += f"{msg.content}\n"
        user_prompt = user_prompt.strip()

        # Generate local app workspace
        app_id = f"app-{uuid.uuid4().hex[:8]}"
        app_dir = WORKSPACE_BASE / app_id
        app_dir.mkdir(parents=True, exist_ok=True)

        RUNNING_JOBS[app_id] = {
            "status": "queued",
            "created_at": created_time,
            "path": str(app_dir)
        }

        # Queue background processing job
        background_tasks.add_task(run_pipeline, app_id=app_id, app_dir=app_dir, prd_content=user_prompt)

        response_text = (
            f"Build pipeline initiated.\n"
            f"App ID: {app_id}\n"
            f"Workspace Path: {app_dir}\n"
            f"Upstream Proxy Target: {TARGET_BACKEND_URL}"
        )

        if req.stream:
            async def stream_generator() -> AsyncGenerator[str, None]:
                chunk_data = {
                    "id": completion_id,
                    "object": "chat.completion.chunk",
                    "created": created_time,
                    "model": req.model,
                    "choices": [{
                        "index": 0,
                        "delta": {"role": "assistant", "content": response_text},
                        "finish_reason": None
                    }]
                }
                yield f"data: {json.dumps(chunk_data)}\n\n"
                
                stop_chunk = {
                    "id": completion_id,
                    "object": "chat.completion.chunk",
                    "created": created_time,
                    "model": req.model,
                    "choices": [{
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop"
                    }]
                }
                yield f"data: {json.dumps(stop_chunk)}\n\n"
                yield "data: [DONE]\n\n"

            return StreamingResponse(stream_generator(), media_type="text/event-stream")

        return {
            "id": completion_id,
            "object": "chat.completion",
            "created": created_time,
            "model": req.model,
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response_text
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": len(user_prompt.split()),
                "completion_tokens": len(response_text.split()),
                "total_tokens": len(user_prompt.split()) + len(response_text.split())
            }
        }
    except Exception as e:
        logger.error(f"Error handling completion request: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# --- Reverse Proxy Fallback Handler ---

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
async def reverse_proxy_fallback(request: Request, path: str):
    """
    Proxies all unhandled requests directly to the downstream backend server with error handling.
    """
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
    except httpx.RequestError as exc:
        logger.error(f"Proxy request error connecting to {url}: {exc}")
        return JSONResponse(
            status_code=502,
            content={
                "error": {
                    "message": f"Bad Gateway: Failed to reach upstream server at {TARGET_BACKEND_URL}",
                    "details": str(exc)
                }
            }
        )

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
