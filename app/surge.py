import os
import re
import subprocess
from pathlib import Path

from .config import SURGE_TOKEN, SURGE_DOMAIN_PREFIX

def deploy_to_surge(
    root: Path,
    job_id: str,
):
    if not SURGE_TOKEN:
        raise RuntimeError(
            "SURGE_TOKEN is required for production Surge deployment."
        )

    if subprocess.call(
        ["bash", "-lc", "command -v surge >/dev/null 2>&1"]
    ) != 0:
        raise RuntimeError(
            "Surge CLI is not installed."
        )

    safe_job = re.sub(
        r"[^a-zA-Z0-9-]",
        "-",
        job_id,
    )

    domain = f"{SURGE_DOMAIN_PREFIX}-{safe_job}.surge.sh"

    env = os.environ.copy()
    env["SURGE_TOKEN"] = SURGE_TOKEN

    command = [
        "surge",
        str(root),
        domain,
    ]

    process = subprocess.run(
        command,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=900,
    )

    if process.returncode != 0:
        raise RuntimeError(
            process.stdout[-10000:]
        )

    return {
        "status": "deployed",
        "domain": domain,
        "url": f"https://{domain}",
        "output": process.stdout[-5000:],
    }
