import json
import os
import logging
from typing import Any

import httpx

from .config import (
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


def _provider_for_model(model: str) -> str:
    model = model.lower()

    if model.startswith("groq/"):
        return "groq"

    if model.startswith("cerebras/"):
        return "cerebras"

    if model.startswith("openrouter/"):
        return "openrouter"

    if model.startswith("anthropic/"):
        return "openrouter"

    if model.startswith("google/"):
        return "openrouter"

    if model.startswith("x-ai/"):
        return "openrouter"

    return "openrouter"


def provider_chain(requested_model: str | None) -> list[str]:
    if requested_model:
        return [requested_model]

    result = [PRIMARY_MODEL]

    for model in FALLBACK_MODELS:
        if model not in result:
            result.append(model)

    if OPENROUTER_API_KEY:
        for model in (
            OPENROUTER_MODEL,
            OPENROUTER_FALLBACK_MODEL,
        ):
            if model and model not in result:
                result.append(model)

    return result


def _credentials_available(provider: str) -> bool:
    if provider == "groq":
        return bool(GROQ_API_KEY)

    if provider == "cerebras":
        return bool(CEREBRAS_API_KEY)

    if provider == "openrouter":
        return bool(OPENROUTER_API_KEY)

    return False


def _url(provider: str) -> str:
    if provider == "groq":
        return GROQ_URL

    if provider == "cerebras":
        return CEREBRAS_URL

    return OPENROUTER_URL


def _headers(provider: str) -> dict[str, str]:
    if provider == "groq":
        key = GROQ_API_KEY
    elif provider == "cerebras":
        key = CEREBRAS_API_KEY
    else:
        key = OPENROUTER_API_KEY

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }

    if provider == "openrouter":
        headers.update(
            {
                "HTTP-Referer": os.getenv(
                    "TRAVELER_PUBLIC_URL",
                    "https://traveler-dev.onrender.com",
                ),
                "X-Title": "TRAVELER DEV",
            }
        )

    return headers


async def _request(
    provider: str,
    model: str,
    messages: list[dict[str, Any]],
    temperature: float,
    max_tokens: int,
) -> dict[str, Any]:
    if not _credentials_available(provider):
        raise ProviderError(
            f"{provider.upper()} API key is not configured."
        )

    payload = {
        "model": model.removeprefix(f"{provider}/"),
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }

    timeout = httpx.Timeout(
        connect=30.0,
        read=180.0,
        write=60.0,
        pool=30.0,
    )

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            _url(provider),
            headers=_headers(provider),
            json=payload,
        )

    if response.status_code >= 400:
        raise ProviderError(
            json.dumps(
                {
                    "provider": provider,
                    "model": model,
                    "status": response.status_code,
                    "body": response.text[:4000],
                },
                ensure_ascii=False,
            )
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise ProviderError(
            f"{provider} returned invalid JSON."
        ) from exc

    choices = data.get("choices") or []

    if not choices:
        raise ProviderError(
            f"{provider} returned no choices."
        )

    message = choices[0].get("message") or {}
    content = message.get("content")

    if isinstance(content, list):
        content = "".join(
            item.get("text", "")
            for item in content
            if isinstance(item, dict)
        )

    if not isinstance(content, str) or not content.strip():
        raise ProviderError(
            f"{provider} returned empty assistant content."
        )

    return {
        "provider": provider,
        "model": model,
        "content": content,
        "raw": data,
    }


async def chat(
    messages: list[dict[str, Any]],
    model: str | None = None,
    temperature: float = 0.2,
    max_tokens: int = 16000,
) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []

    for candidate in provider_chain(model):
        provider = _provider_for_model(candidate)

        try:
            result = await _request(
                provider=provider,
                model=candidate,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )

            logger.info(
                "LLM request succeeded provider=%s model=%s",
                provider,
                candidate,
            )

            return result

        except Exception as exc:
            logger.warning(
                "LLM provider failed provider=%s model=%s error=%s",
                provider,
                candidate,
                exc,
            )

            errors.append(
                {
                    "provider": provider,
                    "model": candidate,
                    "error": str(exc),
                }
            )

    raise ProviderError(
        json.dumps(
            {
                "message": "All configured models failed.",
                "attempts": errors,
            },
            ensure_ascii=False,
        )
    )


def provider_status() -> dict[str, Any]:
    return {
        "primary": PRIMARY_MODEL,
        "fallbacks": FALLBACK_MODELS,
        "credentials": {
            "groq": bool(GROQ_API_KEY),
            "cerebras": bool(CEREBRAS_API_KEY),
            "openrouter": bool(OPENROUTER_API_KEY),
        },
        "openrouter": {
            "model": OPENROUTER_MODEL,
            "fallback_model": OPENROUTER_FALLBACK_MODEL,
        },
    }
