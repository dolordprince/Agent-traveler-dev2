import asyncio
import logging
import uuid
from typing import Any

from fastapi import (
    Depends,
    FastAPI,
    HTTPException,
    Request,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import (
    FileResponse,
    JSONResponse,
)
from pydantic import BaseModel, Field

from app.agent import run_agent
from app.artifacts import (
    build_mobile_package,
    build_zip,
)
from app.config import (
    FALLBACK_MODELS,
    PRIMARY_MODEL,
)
from app.preview import (
    start_preview,
    status_preview,
    stop_preview,
)
from app.providers import (
    chat,
    provider_status,
)
from app.security import require_api_key
from app.surge import deploy_to_surge
from app.workspace import (
    execute_command,
    list_files,
    read_file,
    resolve_workspace,
)


logging.basicConfig(
    level=logging.INFO
)

logger = logging.getLogger(
    "traveler"
)


app = FastAPI(
    title="TRAVELER DEV Production Agent",
    version="3.0.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


JOBS: dict[str, dict[str, Any]] = {}


class CodeRequest(BaseModel):
    project_id: str
    workspace_path: str
    user_instruction: str
    knowledge_context: list[str] = Field(
        default_factory=list
    )
    build_after_edit: bool = True
    test_after_edit: bool = True
    start_preview: bool = True


class PreviewRequest(BaseModel):
    job_id: str


class DeployRequest(BaseModel):
    job_id: str
    confirmed: bool


class CommandRequest(BaseModel):
    job_id: str
    command: str
    timeout: int | None = None


def job_or_404(job_id: str):
    job = JOBS.get(job_id)

    if not job:
        raise HTTPException(
            status_code=404,
            detail="Job not found.",
        )

    return job


async def run_project_command(
    root,
    command: str,
):
    return await execute_command(
        command,
        root,
    )


@app.get("/")
async def root():
    return {
        "name": "TRAVELER DEV",
        "status": "operational",
        "service": "production-agent-backend",
        "version": app.version,
        "preview_before_deployment": True,
        "deployment_requires_user_confirmation": True,
    }


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "traveler-dev-agent",
        "providers": provider_status(),
    }


@app.get("/api/health")
async def api_health():
    return await health()


@app.get("/api/config")
async def config():
    return {
        "name": "TRAVELER DEV",
        "preview_before_deployment": True,
        "download_available": True,
        "surge_available": True,
        "primary_model": PRIMARY_MODEL,
        "fallback_models": FALLBACK_MODELS,
        "providers": provider_status(),
    }


@app.get("/api/providers")
async def providers():
    return provider_status()


@app.get("/api/provider/status")
async def provider_status_endpoint():
    return provider_status()


@app.post(
    "/api/provider/run",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def provider_run(request: Request):
    body = await request.json()

    result = await chat(
        messages=body.get(
            "messages",
            [],
        ),
        model=body.get("model"),
        temperature=body.get(
            "temperature",
            0.2,
        ),
        max_tokens=body.get(
            "max_tokens",
            16000,
        ),
    )

    return result


@app.post(
    "/api/agent/code",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def create_code_job(
    request: CodeRequest,
):
    job_id = (
        f"job_{uuid.uuid4().hex}"
    )

    job = {
        "job_id": job_id,
        "project_id": request.project_id,
        "workspace_path": request.workspace_path,
        "status": "running",
        "phase": "coding",
        "logs": [],
    }

    JOBS[job_id] = job

    try:
        result = await run_agent(
            workspace_path=request.workspace_path,
            instruction=request.user_instruction,
            knowledge_names=request.knowledge_context,
        )

        job["agent"] = result
        job["phase"] = "build"

        root = resolve_workspace(
            request.workspace_path
        )

        if request.build_after_edit:
            build_result = await run_project_command(
                root,
                "npm run build",
            )

            job["build"] = build_result

            if build_result["returncode"] != 0:
                job["status"] = "failed"
                job["phase"] = "build_failed"
                return job

        job["phase"] = "testing"

        if request.test_after_edit:
            test_result = await run_project_command(
                root,
                "npm test -- --runInBand",
            )

            job["test"] = test_result

            if test_result["returncode"] != 0:
                job["status"] = "failed"
                job["phase"] = "test_failed"
                return job

        if request.start_preview:
            job["phase"] = "preview"

            preview_result = start_preview(
                job_id,
                root,
            )

            job["preview"] = preview_result

        job["status"] = "awaiting_user"
        job["phase"] = "user_review"

        job["deployment"] = {
            "allowed": False,
            "status": "waiting_for_user",
        }

        return job

    except Exception as exc:
        logger.exception(
            "Agent job failed"
        )

        job["status"] = "failed"
        job["phase"] = "error"
        job["error"] = str(exc)

        return job


@app.get(
    "/api/agent/code/{job_id}",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def get_code_job(
    job_id: str,
):
    return job_or_404(job_id)


@app.get(
    "/api/agent/jobs/{job_id}",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def get_job(
    job_id: str,
):
    return job_or_404(job_id)


@app.get(
    "/api/agent/code/{job_id}/logs",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def get_logs(
    job_id: str,
):
    job = job_or_404(job_id)

    return {
        "job_id": job_id,
        "logs": job.get(
            "logs",
            [],
        ),
        "agent": job.get("agent"),
        "build": job.get("build"),
        "test": job.get("test"),
        "error": job.get("error"),
    }


@app.post(
    "/api/agent/preview",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def preview(
    request: PreviewRequest,
):
    job = job_or_404(
        request.job_id
    )

    root = resolve_workspace(
        job["workspace_path"]
    )

    result = start_preview(
        request.job_id,
        root,
    )

    job["preview"] = result
    job["phase"] = "user_review"
    job["status"] = "awaiting_user"

    return result


@app.get(
    "/api/agent/jobs/{job_id}/preview/status",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def preview_status(
    job_id: str,
):
    job_or_404(job_id)

    return status_preview(
        job_id
    )


@app.post(
    "/api/agent/preview/{job_id}/stop",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def stop_job_preview(
    job_id: str,
):
    job_or_404(job_id)

    return stop_preview(
        job_id
    )


@app.post(
    "/api/agent/test",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def test_project(
    request: PreviewRequest,
):
    job = job_or_404(
        request.job_id
    )

    root = resolve_workspace(
        job["workspace_path"]
    )

    result = await run_project_command(
        root,
        "npm test -- --runInBand",
    )

    job["test"] = result

    return result


@app.post(
    "/api/agent/command",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def command(
    request: CommandRequest,
):
    job = job_or_404(
        request.job_id
    )

    root = resolve_workspace(
        job["workspace_path"]
    )

    return await execute_command(
        request.command,
        root,
        request.timeout,
    )


@app.get(
    "/api/agent/jobs/{job_id}/files",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def files(
    job_id: str,
):
    job = job_or_404(job_id)

    root = resolve_workspace(
        job["workspace_path"]
    )

    return {
        "files": list_files(root)
    }


@app.get(
    "/api/agent/jobs/{job_id}/file",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def file_content(
    job_id: str,
    path: str,
):
    job = job_or_404(job_id)

    root = resolve_workspace(
        job["workspace_path"]
    )

    return {
        "path": path,
        "content": read_file(
            root,
            path,
        ),
    }


@app.post(
    "/api/agent/download/web",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def download_web(
    request: PreviewRequest,
):
    job = job_or_404(
        request.job_id
    )

    root = resolve_workspace(
        job["workspace_path"]
    )

    artifact = build_zip(
        root,
        request.job_id,
    )

    return FileResponse(
        artifact,
        filename=artifact.name,
        media_type="application/zip",
    )


@app.post(
    "/api/agent/download/mobile",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def download_mobile(
    request: PreviewRequest,
):
    job = job_or_404(
        request.job_id
    )

    root = resolve_workspace(
        job["workspace_path"]
    )

    artifact = build_mobile_package(
        root,
        request.job_id,
    )

    return FileResponse(
        artifact,
        filename=artifact.name,
        media_type="application/zip",
    )


@app.post(
    "/api/agent/deploy/surge",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def deploy_surge_endpoint(
    request: DeployRequest,
):
    job = job_or_404(
        request.job_id
    )

    if not request.confirmed:
        raise HTTPException(
            status_code=400,
            detail=(
                "Explicit deployment confirmation "
                "is required."
            ),
        )

    if job.get("status") != "awaiting_user":
        raise HTTPException(
            status_code=409,
            detail=(
                "Project is not awaiting "
                "deployment decision."
            ),
        )

    preview = job.get("preview")

    if not preview:
        raise HTTPException(
            status_code=409,
            detail=(
                "A successful preview is required "
                "before deployment."
            ),
        )

    if not status_preview(
        request.job_id
    ).get("running"):
        raise HTTPException(
            status_code=409,
            detail=(
                "Preview must be running "
                "before deployment."
            ),
        )

    test = job.get("test")

    if test and test.get(
        "returncode"
    ) != 0:
        raise HTTPException(
            status_code=409,
            detail=(
                "Project tests must pass "
                "before deployment."
            ),
        )

    root = resolve_workspace(
        job["workspace_path"]
    )

    job["phase"] = "deploying"

    try:
        result = deploy_to_surge(
            root,
            request.job_id,
        )

        job["deployment"] = result
        job["status"] = "deployed"
        job["phase"] = "complete"

        return result

    except Exception as exc:
        job["status"] = "failed"
        job["phase"] = "deployment_failed"
        job["error"] = str(exc)
        raise


@app.post(
    "/v1/chat/completions",
    dependencies=[
        Depends(require_api_key)
    ],
)
async def openai_compat(
    request: Request,
):
    body = await request.json()

    result = await chat(
        messages=body.get(
            "messages",
            [],
        ),
        model=body.get("model"),
        temperature=body.get(
            "temperature",
            0.2,
        ),
        max_tokens=body.get(
            "max_tokens",
            16000,
        ),
    )

    return JSONResponse(
        {
            "id": (
                f"chatcmpl_"
                f"{uuid.uuid4().hex}"
            ),
            "object": "chat.completion",
            "model": result["model"],
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": result[
                            "content"
                        ],
                    },
                    "finish_reason": "stop",
                }
            ],
        }
    )


@app.on_event("shutdown")
async def shutdown_event():
    for job_id in list(JOBS):
        try:
            stop_preview(job_id)
        except Exception:
            logger.exception(
                "Failed stopping preview %s",
                job_id,
            )
