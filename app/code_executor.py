import subprocess
import os
import uuid
from app.config import WORKSPACE_DIR, PREVIEW_BASE_PORT

class CodeExecutor:
    def __init__(self):
        self.active_previews = {}

    async def create_project(self, name: str, files: dict) -> str:
        project_id = str(uuid.uuid4())[:8]
        project_path = os.path.join(WORKSPACE_DIR, project_id)
        os.makedirs(project_path, exist_ok=True)

        for path, content in files.items():
            full_path = os.path.join(project_path, path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)

        subprocess.Popen(["npm", "install"], cwd=project_path, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return project_id

    async def run_preview(self, project_id: str) -> int:
        project_path = os.path.join(WORKSPACE_DIR, project_id)
        port = PREVIEW_BASE_PORT + len(self.active_previews)
        proc = subprocess.Popen(["npm", "run", "dev", "--", "--port", str(port)], cwd=project_path)
        self.active_previews[project_id] = {"port": port, "proc": proc}
        return port

executor = CodeExecutor()
