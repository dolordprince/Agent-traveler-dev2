#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${RENDER_URL:-https://agent-traveler-dev2.onrender.com}"
BASE_URL="${BASE_URL%/}"

PASS=0
FAIL=0

pass() {
    printf '[PRODUCTION][PASS] %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf '[PRODUCTION][FAIL] %s\n' "$1"
    FAIL=$((FAIL + 1))
}

request() {
    curl --fail-with-body \
        --silent \
        --show-error \
        --max-time 30 \
        "$@"
}

echo "============================================================"
echo "TRAVELER DEV — RENDER PRODUCTION VERIFICATION"
echo "============================================================"
echo "URL: $BASE_URL"
echo

if health="$(request "$BASE_URL/health")"; then
    printf '%s\n' "$health"
    pass "Live /health"
else
    fail "Live /health"
fi

if root="$(request "$BASE_URL/")"; then
    printf '%s\n' "$root"
    pass "Live root API"
else
    fail "Live root API"
fi

if config="$(request "$BASE_URL/api/config")"; then
    printf '%s\n' "$config"
    pass "Live /api/config"
else
    fail "Live /api/config"
fi

if providers="$(request "$BASE_URL/api/providers")"; then
    printf '%s\n' "$providers"
    pass "Live /api/providers"
else
    fail "Live /api/providers"
fi

echo
echo "============================================================"
echo "RESULT"
echo "PASS=$PASS FAIL=$FAIL"
echo "============================================================"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

echo "OVERALL: PASS"
