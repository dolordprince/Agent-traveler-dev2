import httpx
import time

payload = {
    "project_id": "prod-test-03",
    "workspace_path": "/root/traveler-dev-agent",
    "user_instruction": "Create a production status summary module.",
    "build_after_edit": False,
    "test_after_edit": False,
    "deploy_to_surge": False,
    "package_mobile": True
}

res = httpx.post("http://127.0.0.1:8000/api/agent/code", json=payload, timeout=10)
job_id = res.json()["job_id"]
print("Job Queued:", job_id)

# Poll until job finishes
for _ in range(30):
    status_res = httpx.get(f"http://127.0.0.1:8000/api/agent/code/{job_id}").json()
    print(f"Current Phase: {status_res['current_phase']}, Status: {status_res['status']}")
    if status_res["status"] in ["succeeded", "failed"]:
        break
    time.sleep(2)

# Test downloads now that it is complete
web_dl = httpx.get(f"http://127.0.0.1:8000/api/agent/code/{job_id}/download/web")
mobile_dl = httpx.get(f"http://127.0.0.1:8000/api/agent/code/{job_id}/download/mobile")
print("Web Download Status:", web_dl.status_code, len(web_dl.content), "bytes")
print("Mobile Download Status:", mobile_dl.status_code, len(mobile_dl.content), "bytes")
