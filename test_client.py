import httpx
import time
import sys
import json

BASE_URL = "http://127.0.0.1:8000"

def run_test():
    print("🚀 Dispatching test agent coding job...")
    payload = {
        "project_id": "test-project-alpha",
        "workspace_path": "/root/traveler-dev-agent",
        "user_instruction": "Verify workspace integration and apply FastAPI patterns.",
        "knowledge_context": ["FastAPI-Patterns.md"],
        "build_after_edit": False,
        "start_preview": True
    }
    
    with httpx.Client(base_url=BASE_URL, timeout=30.0) as client:
        # 1. Create Job via POST endpoint
        res = client.post("/api/agent/code", json=payload)
        if res.status_code != 201:
            print(f"❌ Failed to create job: {res.status_code} - {res.text}")
            sys.exit(1)
            
        job_data = res.json()
        job_id = job_data["job_id"]
        print(f"✅ Job created successfully! ID: {job_id}")
        
        # 2. Poll status endpoint until completion
        print("⏳ Polling asynchronous job status...")
        while True:
            status_res = client.get(f"/api/agent/code/{job_id}")
            status_data = status_res.json()
            current_status = status_data["status"]
            phase = status_data["current_phase"]
            print(f"   -> Current Phase: {phase} | Status: {current_status}")
            
            if current_status in ["succeeded", "failed"]:
                print("\n📦 --- Final Job Result ---")
                print(json.dumps(status_data, indent=2))
                break
            time.sleep(2)
            
        # 3. Retrieve logs endpoint
        logs_res = client.get(f"/api/agent/code/{job_id}/logs")
        print("\n📜 --- Execution Logs ---")
        for log in logs_res.json().get("logs", []):
            print(log)

if __name__ == "__main__":
    run_test()
