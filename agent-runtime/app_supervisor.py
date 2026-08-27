import asyncio
import os
import urllib.request
import urllib.error
from typing import Dict, Any, Optional

class ProcessSupervisor:
    """Manages background application processes using standard libraries only."""
    
    def __init__(self):
        self.process: Optional[asyncio.subprocess.Process] = None
        self.log_buffer = []
        self.target_url = None

    async def _read_stream(self, stream, prefix: str):
        try:
            while not stream.at_eof():
                line = await stream.readline()
                if line:
                    decoded = line.decode('utf-8').strip()
                    self.log_buffer.append(f"[{prefix}] {decoded}")
                    if len(self.log_buffer) > 100:
                        self.log_buffer.pop(0)
        except Exception:
            pass

    async def start_app(self, command: str, directory: str, port: int) -> Dict[str, Any]:
        if self.process is not None:
            return {"status": "error", "message": "A process is already running. Stop it first."}

        self.log_buffer = []
        self.target_url = f"http://localhost:{port}"
        
        try:
            self.process = await asyncio.create_subprocess_shell(
                command,
                cwd=directory,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                preexec_fn=os.setsid
            )
            
            asyncio.create_task(self._read_stream(self.process.stdout, "STDOUT"))
            asyncio.create_task(self._read_stream(self.process.stderr, "STDERR"))
            
            is_ready = await self._wait_for_port(self.target_url, timeout_secs=15)
            
            if is_ready:
                return {"status": "success", "url": self.target_url, "message": f"App running at {self.target_url}"}
            else:
                await self.stop_app()
                return {
                    "status": "error", 
                    "message": f"Server failed to start or bind to port {port}.",
                    "logs": "\n".join(self.log_buffer)
                }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    async def _check_url(self, url: str) -> bool:
        def sync_check():
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'SupervisorCheck'})
                with urllib.request.urlopen(req, timeout=1) as response:
                    return response.status == 200
            except Exception:
                return False
        return await asyncio.to_thread(sync_check)

    async def _wait_for_port(self, url: str, timeout_secs: int) -> bool:
        for _ in range(timeout_secs):
            if self.process and self.process.returncode is not None:
                return False
            if await self._check_url(url):
                return True
            await asyncio.sleep(1)
        return False

    async def stop_app(self) -> Dict[str, Any]:
        if self.process:
            try:
                import signal
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                await self.process.wait()
            except Exception:
                pass
            
            self.process = None
            self.target_url = None
            return {"status": "success", "message": "Process terminated."}
        return {"status": "success", "message": "No process was running."}

    def get_logs(self) -> str:
        return "\n".join(self.log_buffer)
