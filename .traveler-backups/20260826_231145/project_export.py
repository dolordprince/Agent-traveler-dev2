from __future__ import annotations

import io
import os
import re
import zipfile
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse


router = APIRouter(
    prefix="/api/projects",
    tags=["project-export"],
)


_PROJECT_ID_RE = re.compile(
    r"^[A-Za-z0-9._-]{1,160}$"
)


_EXCLUDED_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".venv",
    "venv",
    "node_modules",
    "__pycache__",
    ".next",
    "dist",
    "build",
    ".cache",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".tox",
}


_EXCLUDED_FILES = {
    ".DS_Store",
}


_SECRET_FILE_NAMES = {
    ".env",
    ".env.local",
    ".env.production",
    ".env.development",
    ".env.test",
    ".env.staging",
}


_SECRET_PATTERNS = (
    re.compile(r"(^|/)\.env($|\.)", re.IGNORECASE),
    re.compile(r"(^|/).*credentials.*", re.IGNORECASE),
    re.compile(r"(^|/).*secret.*", re.IGNORECASE),
    re.compile(r"(^|/).*private[_-]?key.*", re.IGNORECASE),
)


def _workspace_root() -> Path:
    configured = os.getenv("WORKSPACE_ROOT")

    if configured:
        root = Path(configured).expanduser().resolve()
    else:
        root = Path(__file__).resolve().parent.parent / "workspace"

    root.mkdir(
        parents=True,
        exist_ok=True,
    )

    return root


def _safe_project_id(project_id: str) -> str:
    if not _PROJECT_ID_RE.fullmatch(project_id):
        raise HTTPException(
            status_code=400,
            detail="Invalid project_id.",
        )

    return project_id


def _project_candidates(project_id: str) -> list[Path]:
    root = _workspace_root()

    candidates = [
        root / project_id,
        root / "projects" / project_id,
        Path.cwd() / "projects" / project_id,
        Path.cwd() / "workspace" / project_id,
    ]

    result: list[Path] = []
    seen: set[str] = set()

    for candidate in candidates:
        try:
            resolved = candidate.resolve()
        except OSError:
            continue

        key = str(resolved)

        if key in seen:
            continue

        seen.add(key)
        result.append(resolved)

    return result


def _locate_project(project_id: str) -> Path:
    root = _workspace_root().resolve()

    for candidate in _project_candidates(project_id):
        if not candidate.exists() or not candidate.is_dir():
            continue

        try:
            candidate.relative_to(root)
            return candidate
        except ValueError:
            pass

        # Support the conventional repository-local projects/<id>
        # location when WORKSPACE_ROOT is configured elsewhere.
        try:
            candidate.relative_to(Path.cwd().resolve())
            return candidate
        except ValueError:
            continue

    raise HTTPException(
        status_code=404,
        detail=f"Project '{project_id}' was not found.",
    )


def _excluded(relative_path: Path) -> bool:
    parts = relative_path.parts

    if any(part in _EXCLUDED_DIRS for part in parts):
        return True

    if relative_path.name in _EXCLUDED_FILES:
        return True

    if relative_path.name in _SECRET_FILE_NAMES:
        return True

    normalized = relative_path.as_posix()

    if any(
        pattern.search(normalized)
        for pattern in _SECRET_PATTERNS
    ):
        return True

    return False


def _build_zip(
    project_id: str,
    project_root: Path,
) -> bytes:

    output = io.BytesIO()
    files_added = 0

    project_root = project_root.resolve()

    with zipfile.ZipFile(
        output,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
    ) as archive:

        for path in sorted(project_root.rglob("*")):

            if not path.is_file():
                continue

            try:
                relative = path.relative_to(project_root)
            except ValueError:
                continue

            if _excluded(relative):
                continue

            if path.is_symlink():
                try:
                    path.resolve().relative_to(project_root)
                except ValueError:
                    continue

            archive_name = (
                Path(project_id) / relative
            ).as_posix()

            archive.write(
                path,
                archive_name,
            )

            files_added += 1

        if files_added == 0:
            raise HTTPException(
                status_code=404,
                detail=(
                    f"Project '{project_id}' contains "
                    "no exportable files."
                ),
            )

        manifest = (
            "TRAVELER DEV PROJECT EXPORT\n"
            f"project_id={project_id}\n"
            f"files={files_added}\n"
        )

        archive.writestr(
            (
                Path(project_id)
                / "TRAVELER-DEV-EXPORT.txt"
            ).as_posix(),
            manifest,
        )

    output.seek(0)

    return output.getvalue()


@router.get(
    "/{project_id}/export.zip",
    name="export_project_zip",
    summary="Export complete project as ZIP",
)
def export_project_zip(
    project_id: str,
) -> StreamingResponse:

    project_id = _safe_project_id(
        project_id
    )

    project_root = _locate_project(
        project_id
    )

    payload = _build_zip(
        project_id,
        project_root,
    )

    filename = f"{project_id}.zip"

    return StreamingResponse(
        io.BytesIO(payload),
        media_type="application/zip",
        headers={
            "Content-Disposition": (
                f'attachment; filename="{filename}"'
            ),
            "Content-Length": str(len(payload)),
            "Cache-Control": "no-store",
        },
    )
