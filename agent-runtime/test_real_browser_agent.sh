#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${TRAVELER_AGENT_URL:-http://127.0.0.1:8090}"
WORKSPACE="/root/Agent-traveler-dev2/workspace/browser-agent-real-test"

echo "============================================================"
echo "TRAVELER DEV — REAL PLAYWRIGHT AGENT ACCEPTANCE TEST"
echo "============================================================"

curl -fsS "${BASE_URL}/health" >/dev/null

rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"

cat > "$WORKSPACE/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Traveler Dev Browser Acceptance</title>
</head>
<body>
  <main>
    <h1>Traveler Dev Browser Acceptance</h1>

    <button id="load-user" type="button">
      Load User
    </button>

    <button id="calculate" type="button">
      Calculate
    </button>

    <div id="status">Ready</div>
    <div id="result"></div>
  </main>

  <script>
    const status = document.getElementById("status");
    const result = document.getElementById("result");

    document.getElementById("load-user").addEventListener("click", () => {
      const user = {
        name: "Traveler Developer"
      };

      status.textContent = "User loaded";
      result.textContent = user.name;
    });

    document.getElementById("calculate").addEventListener("click", () => {
      const values = [10, 20, 30];

      status.textContent = "Calculation complete";
      result.textContent = String(
        values.reduce((sum, value) => sum + value, 0)
      );
    });
  </script>
</body>
</html>
HTML

PROMPT=$(cat <<PROMPT
Perform a REAL browser end-to-end verification of this application.

Workspace:
$WORKSPACE

You MUST use the browser and supervisor tools.

Required sequence:

1. Inspect the workspace.
2. Start the application with supervisor_start_app.
3. Navigate to the returned real URL with browser_navigate.
4. Verify the page title.
5. Click #load-user with browser_click.
6. Read #status and #result using browser_text.
7. Confirm status is exactly "User loaded".
8. Confirm result is exactly "Traveler Developer".
9. Click #calculate with browser_click.
10. Read #status and #result again.
11. Confirm status is exactly "Calculation complete".
12. Confirm result is exactly "60".
13. Call browser_diagnostics.
14. If there are console/page/network errors, diagnose and repair the real application.
15. Re-run the browser interactions after any repair.
16. Capture a browser screenshot.
17. Stop the application.
18. Only report SUCCESS after the real browser interactions have passed.

Do not merely read index.html and claim success.
Do not simulate browser calls.
Do not fabricate results.
Do not create a fake test report.
PROMPT
)

python3 - "$BASE_URL" "$PROMPT" <<'PY'
import json
import sys
import urllib.request

base = sys.argv[1]
prompt = sys.argv[2]

payload = json.dumps({
    "prompt": prompt,
    "maxSteps": 50,
}).encode()

request = urllib.request.Request(
    f"{base}/api/agent/run",
    data=payload,
    headers={
        "Content-Type": "application/json",
    },
    method="POST",
)

with urllib.request.urlopen(request, timeout=300) as response:
    body = response.read().decode()

print(body)
PY

echo
echo "============================================================"
echo "INDEPENDENT BRIDGE HEALTH"
echo "============================================================"

curl -fsS http://127.0.0.1:8091/health

echo
echo
echo "============================================================"
echo "BROWSER AGENT TEST FINISHED"
echo "============================================================"

echo
echo "Inspect runtime log:"
tail -80 runtime.log || true

echo
echo "Inspect browser bridge log:"
tail -80 browser_bridge.log || true
