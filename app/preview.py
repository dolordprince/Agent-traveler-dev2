import json
import os
import socket
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

from .config import (
    PREVIEW_DIR,
    PREVIEW_SHUTDOWN_TIMEOUT,
    PREVIEW_START_TIMEOUT,
)


PROCESSES: dict[str, subprocess.Popen] = {}
LOG_FILES: dict[str, object] = {}


def free_port() -> int:
    sock = socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    )

    try:
        sock.bind(
            ("127.0.0.1", 0)
        )
        return sock.getsockname()[1]
    finally:
        sock.close()


def detect_command(root: Path):
    package = root / "package.json"

    if not package.is_file():
        raise RuntimeError(
            "Generated application has no package.json."
        )

    try:
        data = json.loads(
            package.read_text(
                encoding="utf-8"
            )
        )
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Invalid package.json: {exc}"
        ) from exc

    scripts = data.get("scripts") or {}

    if "start" in scripts:
        return ["npm", "run", "start"]

    if "preview" in scripts:
        return [
            "npm",
            "run",
            "preview",
            "--",
            "--host",
            "0.0.0.0",
        ]

    if "dev" in scripts:
        return [
            "npm",
            "run",
            "dev",
            "--",
            "--host",
            "0.0.0.0",
        ]

    raise RuntimeError(
        "No start, preview, or dev script exists."
    )


def _port_open(port: int) -> bool:
    sock = socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    )

    try:
        sock.settimeout(0.5)
        return (
            sock.connect_ex(
                ("127.0.0.1", port)
            )
            == 0
        )
    finally:
        sock.close()


def _wait_for_preview(
    process: subprocess.Popen,
    port: int,
    log_path: Path,
):
    deadline = time.monotonic() + PREVIEW_START_TIMEOUT

    while time.monotonic() < deadline:
        if process.poll() is not None:
            output = log_path.read_text(
                encoding="utf-8",
                errors="replace",
            )

            raise RuntimeError(
                f"Preview exited with code "
                f"{process.returncode}: "
                f"{output[-10000:]}"
            )

        if _port_open(port):
            return

        time.sleep(0.25)

    output = log_path.read_text(
        encoding="utf-8",
        errors="replace",
    )

    raise RuntimeError(
        "Preview did not open its HTTP port "
        f"within {PREVIEW_START_TIMEOUT}s. "
        f"Output: {output[-10000:]}"
    )


def start_preview(
    job_id: str,
    root: Path,
):
    existing = PROCESSES.get(job_id)

    if existing and existing.poll() is None:
        return {
            "job_id": job_id,
            "pid": existing.pid,
            "port": None,
            "running": True,
            "local_url": None,
            "log": str(
                PREVIEW_DIR / f"{job_id}.log"
            ),
        }

    command = detect_command(root)
    port = free_port()

    log_path = PREVIEW_DIR / f"{job_id}.log"

    log_file = log_path.open(
        "w",
        encoding="utf-8",
    )

    env = os.environ.copy()
    env["PORT"] = str(port)
    env["HOST"] = "0.0.0.0"

    process = subprocess.Popen(
        command,
        cwd=str(root),
        stdout=log_file,
        stderr=subprocess.STDOUT,
        env=env,
        start_new_session=True,
    )

    PROCESSES[job_id] = process
    LOG_FILES[job_id] = log_file

    try:
        _wait_for_preview(
            process,
            port,
            log_path,
        )
    except Exception:
        stop_preview(job_id)
        raise

    return {
        "job_id": job_id,
        "pid": process.pid,
        "port": port,
        "running": True,
        "local_url": f"http://127.0.0.1:{port}",
        "log": str(log_path),
    }


def stop_preview(job_id: str):
    process = PROCESSES.pop(
        job_id,
        None,
    )

    log_file = LOG_FILES.pop(
        job_id,
        None,
    )

    stopped = True

    if process and process.poll() is None:
        try:
            os.killpg(
                process.pid,
                15,
            )

            try:
                process.wait(
                    timeout=PREVIEW_SHUTDOWN_TIMEOUT
                )
            except subprocess.TimeoutExpired:
                os.killpg(
                    process.pid,
                    9,
                )
                process.wait(
                    timeout=5
                )
        except ProcessLookupError:
            pass

    if log_file:
        try:
            log_file.close()
        except Exception:
            pass

    return {
        "job_id": job_id,
        "stopped": stopped,
    }


def status_preview(job_id: str):
    process = PROCESSES.get(job_id)

    if not process:
        return {
            "job_id": job_id,
            "running": False,
        }

    running = process.poll() is None

    return {
        "job_id": job_id,
        "running": running,
        "pid": process.pid,
        "returncode": (
            None
            if running
            else process.returncode
        ),
    }
