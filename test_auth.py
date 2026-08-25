import httpx

BASE_URL = "http://127.0.0.1:8000"
VALID_API_KEY = "prod-secret-key-12345"
INVALID_API_KEY = "invalid-key-xyz"

payload = {
    "prompt": "Write a python function for binary search.",
    "model": "anthropic/claude-3.5-sonnet"
}

print("=== 1. Testing Unauthenticated Request (Expecting 401) ===")
res1 = httpx.post(f"{BASE_URL}/api/agent/code", json=payload)
print(f"Status Code: {res1.status_code}")
print(f"Response: {res1.json()}\n")

print("=== 2. Testing Invalid Key (Expecting 403) ===")
res2 = httpx.post(f"{BASE_URL}/api/agent/code", json=payload, headers={"X-API-Key": INVALID_API_KEY})
print(f"Status Code: {res2.status_code}")
print(f"Response: {res2.json()}\n")

print("=== 3. Testing Valid X-API-Key Header (Expecting 200) ===")
res3 = httpx.post(f"{BASE_URL}/api/agent/code", json=payload, headers={"X-API-Key": VALID_API_KEY}, timeout=30.0)
print(f"Status Code: {res3.status_code}")
print(f"Response: {res3.json()}\n")

print("=== 4. Testing Valid Authorization Bearer Token (Expecting 200) ===")
res4 = httpx.post(f"{BASE_URL}/api/agent/code", json=payload, headers={"Authorization": f"Bearer {VALID_API_KEY}"}, timeout=30.0)
print(f"Status Code: {res4.status_code}")
print(f"Provider Used: {res4.json().get('provider_used')}")
