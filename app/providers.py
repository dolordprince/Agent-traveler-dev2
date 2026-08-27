import json
import logging
import os
from typing import Any

import httpx

from .config import (
    GEMINI_API_KEY,
    GEMINI_URL,
    GEMINI_MODEL,
    KILO_API_KEY,
    KILO_GATEWAY_URL,
    KILO_MODEL,
    AI_GATEWAY_API_KEY,
    VERCEL_GATEWAY_URL,
    VERCEL_GATEWAY_MODEL,
    CEREBRAS_API_KEY,
    CEREBRAS_URL,
    FALLBACK_MODELS,
    GROQ_API_KEY,
    GROQ_URL,
    OPENROUTER_API_KEY,
    OPENROUTER_FALLBACK_MODEL,
    OPENROUTER_MODEL,
    OPENROUTER_URL,
    PRIMARY_MODEL,
)

logger = logging.getLogger("traveler.providers")


class ProviderError(Exception):
    pass


def _get_credential(provider: str) -> str:
    if provider == "groq":
        return os.environ.get("GROQ_API_KEY", "").strip() or GROQ_API_KEY
    if provider == "cerebras":
        return os.environ.get("CEREBRAS_API_KEY", "").strip() or CEREBRAS_API_KEY
    if provider == "vercel":
        key = os.environ.get("AI_GATEWAY_API_KEY", "") or AI_GATEWAY_API_KEY
    elif provider == "openrouter":
        return os.environ.get("OPENROUTER_API_KEY", "").strip() or OPENROUTER_API_KEY
    return ""


def _provider_for_model(model: str) -> str:
    model_lower = model.lower()
    if model_lower.startswith("groq/"):
        return "groq"
    if model_lower.startswith("cerebras/"):
        return "cerebras"
    return "openrouter"


def provider_chain(requested_model: str | None) -> list[str]:
    if requested_model:
        return [requested_model]
    result = [PRIMARY_MODEL]
    for model in FALLBACK_MODELS:
        if model not in result:
            result.append(model)
    if _get_credential("openrouter"):
        for model in (OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL):
            if model and model not in result:
                result.append(model)
    return result


def _url(provider: str) -> str:
    if provider == "groq":
        return GROQ_URL
    if provider == "cerebras":
        return CEREBRAS_URL
    return OPENROUTER_URL


def _headers(provider: str) -> dict[str, str]:
    key = _get_credential(provider)
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if provider == "vercel":
        key = os.environ.get("AI_GATEWAY_API_KEY", "") or AI_GATEWAY_API_KEY
    elif provider == "openrouter":
        headers["HTTP-Referer"] = "https://traveler-dev.onrender.com"
        headers["X-Title"] = "TRAVELER DEV"
    return headers


def provider_status() -> dict[str, Any]:
    return {
        "primary": PRIMARY_MODEL,
        "fallbacks": FALLBACK_MODELS,
        "credentials": {
            "groq": bool(_get_credential("groq")),
            "cerebras": bool(_get_credential("cerebras")),
            "openrouter": bool(_get_credential("openrouter")),
        },
        "openrouter": {
            "model": OPENROUTER_MODEL,
            "fallback_model": OPENROUTER_FALLBACK_MODEL,
        },
    }



async def _vercel_chat(
    messages: list[dict],
    model: str | None = None,
) -> dict:
    """Call Vercel AI Gateway with OpenAI-compatible payload."""
    import httpx

    target_model = model or VERCEL_GATEWAY_MODEL
    key = os.environ.get("AI_GATEWAY_API_KEY", "") or AI_GATEWAY_API_KEY

    if not key:
        raise ValueError("AI_GATEWAY_API_KEY is not configured")

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            VERCEL_GATEWAY_URL,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json={
                "model": target_model,
                "messages": messages,
                "max_tokens": 4096,
            },
        )

    if resp.status_code != 200:
        raise ValueError(
            f"Vercel gateway error {resp.status_code}: {resp.text[:400]}"
        )

    data = resp.json()
    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    return {"content": content, "model": target_model, "raw": data}


async def _kilo_chat(
    messages: list[dict],
    model: str | None = None,
) -> dict:
    """Call Kilo AI Gateway — OpenAI-compatible, hundreds of models."""
    import httpx

    target = model or KILO_MODEL
    key = os.environ.get("KILO_API_KEY", "") or KILO_API_KEY

    if not key:
        raise ValueError("KILO_API_KEY is not configured")

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            KILO_GATEWAY_URL,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json={
                "model": target,
                "messages": messages,
                "max_tokens": 4096,
            },
        )

    if resp.status_code != 200:
        raise ValueError(f"Kilo gateway error {resp.status_code}: {resp.text[:400]}")

    data = resp.json()
    content_text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    return {"content": content_text, "model": target, "raw": data}


async def _gemini_chat(
    messages: list[dict],
    model: str | None = None,
) -> dict:
    """Call Google Gemini via OpenAI-compatible endpoint. Free tier available."""
    import httpx

    target = model or GEMINI_MODEL
    key = os.environ.get("GEMINI_API_KEY", "") or GEMINI_API_KEY

    if not key:
        raise ValueError("GEMINI_API_KEY is not configured")

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            GEMINI_URL,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json={
                "model": target,
                "messages": messages,
                "max_tokens": 4096,
            },
        )

    if resp.status_code != 200:
        raise ValueError(f"Gemini error {resp.status_code}: {resp.text[:400]}")

    data = resp.json()
    text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    return {"content": text, "model": target, "raw": data}


async def chat(
    # ── Try Gemini first (free tier, fast) ────────────────────────────────────
    import os as _os
    _gemini_key = _os.environ.get("GEMINI_API_KEY", "") or GEMINI_API_KEY
    if _gemini_key:
        try:
            return await _gemini_chat(messages, "gemini-3.6-flash")
        except Exception as _ge:
            pass  # Fall through to configured providers
    # ────────────────────────────────────────────────────────────────────────
    messages: list[dict[str, Any]],
    model: str | None = None,
    temperature: float = 0.2,
    max_tokens: int | None = None,
    **kwargs: Any,
) -> dict[str, Any]:
    models_to_try = provider_chain(model)
    last_error: Exception | None = None

    async with httpx.AsyncClient(timeout=120.0) as client:
        for target_model in models_to_try:
            provider = _provider_for_model(target_model)
            key = _get_credential(provider)

            if not key:
                logger.warning(f"Skipping provider {provider} for model {target_model}: missing API key")
                last_error = ProviderError(f"Missing API key for provider '{provider}'")
                continue

            clean_model = target_model.split("/", 1)[1] if "/" in target_model and provider in ("groq", "cerebras") else target_model

            payload: dict[str, Any] = {
                "model": clean_model,
                "messages": messages,
                "temperature": temperature,
            }
            if max_tokens is not None:
                payload["max_tokens"] = max_tokens

            try:
                response = await client.post(
                    _url(provider),
                    headers=_headers(provider),
                    json=payload,
                )

                if response.status_code == 200:
                    data = response.json()
                    choices = data.get("choices", [])
                    if choices and "message" in choices[0]:
                        return {
                            "id": data.get("id", ""),
                            "model": target_model,
                            "content": choices[0]["message"].get("content", ""),
                            "choices": choices,
                            "usage": data.get("usage", {}),
                        }
                    raise ProviderError(f"Invalid choice payload structure from provider {provider}")

                error_text = response.text
                logger.error(f"Provider {provider} ({target_model}) failed with HTTP {response.status_code}: {error_text}")
                last_error = ProviderError(f"Provider {provider} HTTP {response.status_code}: {error_text}")

            except httpx.RequestError as exc:
                logger.error(f"Network error calling provider {provider}: {exc}")
                last_error = exc

    raise ProviderError(f"All configured providers failed. Last error: {last_error}")