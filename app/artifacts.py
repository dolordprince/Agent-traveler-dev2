import shutil
import zipfile
from pathlib import Path

from .config import ARTIFACT_DIR

def build_zip(source: Path, job_id: str):
    destination = ARTIFACT_DIR / f"{job_id}-web.zip"

    if destination.exists():
        destination.unlink()

    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as archive:
        for path in source.rglob("*"):
            if not path.is_file():
                continue

            if ".git" in path.parts:
                continue

            archive.write(
                path,
                path.relative_to(source),
            )

    return destination

def build_mobile_package(source: Path, job_id: str):
    destination = ARTIFACT_DIR / f"{job_id}-mobile.zip"

    if destination.exists():
        destination.unlink()

    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as archive:
        for path in source.rglob("*"):
            if path.is_file() and ".git" not in path.parts:
                archive.write(
                    path,
                    path.relative_to(source),
                )

    return destination
