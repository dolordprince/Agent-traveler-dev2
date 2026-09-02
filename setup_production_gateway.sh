#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/4] Writing Production Gateway (server.py) ==="

cat << 'PYEOF' > server.py
import os
import sys
import json
import time
import uuid
import asyncio
import logging
import subprocess
from pathlib import Path
from typing import AsyncGenerator, Dict, Any, List, Optional

import uvicorn
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks, status
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Configure Production Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("gateway")

# Configuration Constants
WORKSPACE_BASE = Path(os.getenv("WORKSPACE_BASE", "/tmp/claw_workspaces")).resolve()
WORKSPACE_BASE.mkdir(parents=True, exist_ok=True)

MODEL_ALIAS = "claude-opus-4"
PORT = 3456

app = FastAPI(title="OpenClaw Production Gateway", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Active App Execution Registry
RUNNING_JOBS: Dict[str, Dict[str, Any]] = {}

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

# --- Core Pipeline Execution (Phase 0 -> Phase 7) ---

async def run_pipeline(app_id: str, app_dir: Path, prd_content: str):
    """
    Executes the full GLM-V PRD-to-App lifecycle on the target directory.
    """
    logger.info(f"Starting build pipeline for app_id: {app_id} in {app_dir}")
    
    # Write PRD Document
    prd_path = app_dir / "prd.md"
    prd_path.write_text(prd_content, encoding="utf-8")
    
    # 1. Skill Execution (Installs & runs @zai-org/glmv-prd-to-app via npx)
    skill_cmd = f"npx --yes skills run @zai-org/glmv-prd-to-app --dir {app_dir}"
    
    RUNNING_JOBS[app_id]["status"] = "building"
    RUNNING_JOBS[app_id]["step"] = "executing_skill"

    proc = await asyncio.create_subprocess_shell(
        skill_cmd,
        cwd=str(app_dir),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    stdout, stderr = await proc.communicate()
    
    if proc.returncode != 0:
        err_msg = stderr.decode('utf-8', errors='replace')
        logger.error(f"Build failed for {app_id}: {err_msg}")
        RUNNING_JOBS[app_id]["status"] = "failed"
        RUNNING_JOBS[app_id]["error"] = err_msg
        return

    # 2. Execution of generated start.sh script
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
        logger.info(f"App {app_id} deployment launched successfully with PID {start_proc.pid}")
    else:
        RUNNING_JOBS[app_id]["status"] = "completed_without_start_script"
        logger.warning(f"No start.sh script found in {app_dir}")

# --- API Endpoints ---

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "timestamp": int(time.time()),
        "active_jobs": len(RUNNING_JOBS),
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
    created_time = int(time.time())
    completion_id = f"chatcmpl-{uuid.uuid4().hex}"
    
    user_prompt = ""
    for msg in req.messages:
        if msg.role == "user":
            user_prompt += f"{msg.content}\n"
    user_prompt = user_prompt.strip()

    # Generate unique workspace for this execution call
    app_id = f"app-{uuid.uuid4().hex[:8]}"
    app_dir = WORKSPACE_BASE / app_id
    app_dir.mkdir(parents=True, exist_ok=True)

    RUNNING_JOBS[app_id] = {
        "status": "queued",
        "created_at": created_time,
        "path": str(app_dir)
    }

    # Queue execution background job
    background_tasks.add_task(run_pipeline, app_id=app_id, app_dir=app_dir, prd_content=user_prompt)

    response_text = (
        f"Request received and processing.\n"
        f"App ID: {app_id}\n"
        f"Workspace initialized at: {app_dir}\n"
        f"Pipeline build queued under GLM-V PRD-to-App specs."
    )

    if req.stream:
        async def stream_generator() -> AsyncGenerator[str, None]:
            chunk_id = completion_id
            
            # Initial chunk
            chunk_data = {
                "id": chunk_id,
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
            
            # Stop chunk
            stop_chunk = {
                "id": chunk_id,
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
PYEOF

echo "=== [2/4] Installing Required Python Dependencies ==="
pip install --break-system-packages --quiet fastapi uvicorn pydantic

echo "=== [3/4] Starting Server Process on Port 3456 ==="
pkill -f "uvicorn server:app" || true
pkill -f "python3 server.py" || true
python3 server.py > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for server startup on port 3456..."
sleep 3

echo "=== [4/4] Running Verification Commands ==="

echo "Testing /health endpoint:"
curl -s http://localhost:3456/health | python3 -m json.tool

echo -e "\nTesting /v1/models endpoint:"
curl -s http://localhost:3456/v1/models | python3 -m json.tool

echo -e "\nTesting /v1/chat/completions endpoint:"
curl -s http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-opus-4",
    "messages": [{"role": "user", "content": "Hello! Build a dashboard app."}]
  }' | python3 -m json.tool

echo -e "\nServer active under PID $SERVER_PID. Logs written to server.log."
