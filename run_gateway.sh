#!/usr/bin/env bash
cd /root/Agent-traveler-dev2

# Load all env vars from .env
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    [[ "$line" != *"="* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key// /}"
    [[ -z "$key" ]] && continue
    export "$key"="$val"
done < .env

echo "GEMINI_API_KEY length: ${#GEMINI_API_KEY}"
echo "OPENROUTER_API_KEY length: ${#OPENROUTER_API_KEY}"

exec ./.venv/bin/python main.py
