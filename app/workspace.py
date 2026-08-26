import asyncio
import os
import shlex
from pathlib import Path

from .config import MAX_COMMAND_SECONDS, MAX_OUTPUT_BYTES


BLOCKED_COMMANDS = {
    "shutdown",
    "reboot",
    "poweroff",
    "halt",
    "init",
    "mkfs",
    "fdisk",
    "parted",
    "mount",
    "umount",
    "swapon",
    "swapoff",
}


def resolve_workspace(path: str) -> Path:
    candidate = Path(path).expanduser().resolve()

    allowed_roots = {
        Path(
            os.getenv(
                "TRAVELER_WORKSPACE_ROOT",
                "/root",
            )
        ).resolve(),
        Path.cwd().resolve(),
    }

    if not any(
        candidate == root or root in candidate.parents
        for root in allowed_roots
    ):
        raise PermissionError(
            f"Workspace path outside permitted roots: {candidate}"
        )

    candidate.mkdir(
        parents=True,
        exist_ok=True,
    )

    return candidate


def _validate_command(command: str) -> None:
    parts = shlex.split(command)

    if not parts:
        raise ValueError("Empty command.")

    executable = Path(parts[0]).name.lower()

    if executable in BLOCKED_COMMANDS:
        raise PermissionError(
            f"Command '{executable}' is prohibited."
        )


async def execute_command(
    command: str,
    cwd: Path,
    timeout: int | None = None,
):
    cwd = resolve_workspace(str(cwd))
    _validate_command(command)

    timeout = timeout or MAX_COMMAND_SECONDS

    process = await asyncio.create_subprocess_exec(
        "/bin/bash",
        "-lc",
        command,
        cwd=str(cwd),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        env=os.environ.copy(),
        start_new_session=True,
    )

    try:
        output, _ = await asyncio.wait_for(
            process.communicate(),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        try:
            os.killpg(
                process.pid,
                15,
            )
        except ProcessLookupError:
            pass

        try:
            await asyncio.wait_for(
                process.wait(),
                timeout=5,
            )
        except asyncio.TimeoutError:
            try:
                os.killpg(
                    process.pid,
                    9,
                )
            except ProcessLookupError:
                pass

            await process.wait()

        raise TimeoutError(
            f"Command exceeded {timeout} seconds."
        )

    if len(output) > MAX_OUTPUT_BYTES:
        output = (
            output[:MAX_OUTPUT_BYTES]
            + b"\n\n[OUTPUT TRUNCATED]\n"
        )

    return {
        "returncode": process.returncode,
        "output": output.decode(
            "utf-8",
            errors="replace",
        ),
    }


def list_files(root: Path):
    root = resolve_workspace(str(root))
    result = []

    for path in sorted(root.rglob("*")):
        if ".git" in path.parts:
            continue

        relative = path.relative_to(root)

        result.append(
            {
                "path": str(relative),
                "type": (
                    "directory"
                    if path.is_dir()
                    else "file"
                ),
            }
        )

    return result


def _safe_path(root: Path, relative: str) -> Path:
    root = resolve_workspace(str(root))
    path = (root / relative).resolve()

    if path != root and root not in path.parents:
        raise PermissionError(
            "Path escapes workspace."
        )

    return path


def read_file(root: Path, relative: str):
    path = _safe_path(root, relative)

    if not path.is_file():
        raise FileNotFoundError(relative)

    return path.read_text(
        encoding="utf-8",
        errors="replace",
    )


def write_file(
    root: Path,
    relative: str,
    content: str,
):
    path = _safe_path(root, relative)

    if path == resolve_workspace(str(root)):
        raise PermissionError(
            "Cannot overwrite workspace root."
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    path.write_text(
        content,
        encoding="utf-8",
    )

    return str(
        path.relative_to(
            resolve_workspace(str(root))
        )
    )
