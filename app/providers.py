from __future__ import annotations

import logging
import os
from typing import Any

import httpx

from .config import (
    CEREBRAS_API_KEY,
    CEREBRAS_URL,
    FALLBACK_MODELS,
    GEMINI_API_KEY,
    GROQ_API_KEY,
    GROQ_URL,
    OPENROUTER_API_KEY,
    OPENROUTER_FALLBACK_MODEL,
    OPENROUTER_MODEL,
    OPENROUTER_URL,
    PRIMARY_MODEL,
    WEBCONTAINER_ENABLED,
)

logger = logging.getLogger("traveler.providers")


TRAVELER_DEV_SYSTEM_PROMPT = (
    "You are Traveler Dev, an autonomous production-grade software engineering agent. "
    "Follow the user's request exactly. "
    "For ordinary chat, answer directly. "
    "For coding requests, produce complete production-ready implementation using the "
    "requested framework, architecture, APIs and constraints. "
    "Do not invent requirements. "
    "Do not force a fixed application type. "
    "Respect explicit output-format instructions. "
    "If the user requests an exact response, return exactly that response."
)


class ProviderError(Exception):
    pass


# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------

_ENV_KEYS = {
    "groq": "GROQ_API_KEY",
    "cerebras": "CEREBRAS_API_KEY",
    "openrouter": "OPENROUTER_API_KEY",
    "gemini": "GEMINI_API_KEY",
}

_CONFIG_KEYS = {
    "groq": GROQ_API_KEY,
    "cerebras": CEREBRAS_API_KEY,
    "openrouter": OPENROUTER_API_KEY,
    "gemini": GEMINI_API_KEY,
}


def _get_credential(provider: str) -> str:
    env_name = _ENV_KEYS.get(provider)
    if not env_name:
        return ""

    value = os.getenv(env_name, "").strip()
    if value:
        return value

    return str(_CONFIG_KEYS.get(provider, "") or "").strip()


# ---------------------------------------------------------------------------
# Provider routing
# ---------------------------------------------------------------------------

def _provider_for_model(model: str) -> str:
    value = (model or "").strip().lower()

    if value.startswith("groq/"):
        return "groq"

    if value.startswith("cerebras/"):
        return "cerebras"

    if value.startswith("gemini/"):
        return "gemini"

    if value.startswith("openrouter/"):
        return "openrouter"

    # Bare model IDs are treated as OpenRouter models when explicitly
    # supplied, otherwise the configured chain determines the provider.
    return "openrouter"


def _clean_model(provider: str, model: str) -> str:
    value = model.strip()

    prefix = f"{provider}/"

    if value.lower().startswith(prefix):
        return value[len(prefix):]

    return value


def _url(provider: str) -> str:
    if provider == "groq":
        return GROQ_URL

    if provider == "cerebras":
        return CEREBRAS_URL

    if provider == "openrouter":
        return OPENROUTER_URL

    raise ProviderError(f"Unsupported provider '{provider}'")


def _headers(provider: str) -> dict[str, str]:
    key = _get_credential(provider)

    if not key:
        raise ProviderError(
            f"Missing API key for provider '{provider}'"
        )

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    if provider == "openrouter":
        headers["HTTP-Referer"] = "https://agent-traveler-dev2.onrender.com"
        headers["X-Title"] = "TRAVELER DEV"

    return headers


# ---------------------------------------------------------------------------
# Provider chain
# ---------------------------------------------------------------------------

def provider_chain(requested_model: str | None) -> list[str]:
    if requested_model:
        return [requested_model.strip()]

    result: list[str] = []

    candidates = [
        PRIMARY_MODEL,
        *FALLBACK_MODELS,
    ]

    # Only add OpenRouter models when an OpenRouter credential exists.
    if _get_credential("openrouter"):
        candidates.extend(
            [
                f"openrouter/{OPENROUTER_MODEL}",
                f"openrouter/{OPENROUTER_FALLBACK_MODEL}",
            ]
        )

    for model in candidates:
        if model and model not in result:
            result.append(model)

    return result


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=httpx.Timeout(
            connect=10.0,
            read=120.0,
            write=30.0,
            pool=10.0,
        ),
        trust_env=False,
        follow_redirects=False,
    )


# ---------------------------------------------------------------------------
# Response normalization
# ---------------------------------------------------------------------------

def _extract_response(data: dict[str, Any], target_model: str) -> dict[str, Any]:
    choices = data.get("choices") or []

    if not choices:
        raise ProviderError(
            f"Provider returned no choices for '{target_model}'"
        )

    first = choices[0] or {}
    message = first.get("message") or {}

    content = message.get("content")

    # gpt-oss can expose useful output through reasoning_content.
    if not content:
        content = message.get("reasoning_content")

    if content is None:
        content = data.get("content")

    if content is None:
        content = ""

    return {
        "id": data.get("id", ""),
        "model": target_model,
        "content": content,
        "choices": choices,
        "usage": data.get("usage", {}),
        "reasoning": message.get("reasoning_content"),
    }


# ---------------------------------------------------------------------------
# Groq live model validation
# ---------------------------------------------------------------------------

async def validate_groq_models(models: list[str]) -> list[str]:
    key = _get_credential("groq")

    if not key:
        return models

    try:
        async with _client() as client:
            response = await client.get(
                "https://api.groq.com/openai/v1/models",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Accept": "application/json",
                },
            )

        if response.status_code != 200:
            logger.warning(
                "Groq model discovery returned HTTP %s",
                response.status_code,
            )
            return models

        payload = response.json()
        available = {
            item.get("id")
            for item in payload.get("data", [])
            if item.get("id")
        }

        validated: list[str] = []

        for model in models:
            bare = _clean_model("groq", model)

            if bare in available:
                validated.append(model)
            else:
                logger.warning(
                    "Groq model '%s' is not currently available",
                    bare,
                )

        return validated or models

    except Exception as exc:
        logger.warning(
            "Groq model discovery failed: %s",
            exc,
        )
        return models


# ---------------------------------------------------------------------------
# WebContainer
# ---------------------------------------------------------------------------

WEBCONTAINER_API_URL = (
    "https://webcontainer.api.stackblitz.com"
)


async def webcontainer_boot(
    project_files: dict[str, str],
) -> dict[str, Any]:
    if not WEBCONTAINER_ENABLED:
        return {
            "status": "disabled",
            "message": "WebContainer integration is disabled",
        }

    payload = {
        "files": {
            path: {
                "file": {
                    "contents": content,
                }
            }
            for path, content in project_files.items()
        }
    }

    try:
        async with _client() as client:
            response = await client.post(
                f"{WEBCONTAINER_API_URL}/v1/boot",
                json=payload,
                headers={
                    "Content-Type": "application/json",
                },
            )

        if response.status_code in (200, 201):
            return {
                "status": "ok",
                "data": response.json(),
            }

        return {
            "status": "error",
            "http_status": response.status_code,
            "message": response.text,
        }

    except Exception as exc:
        logger.error(
            "WebContainer boot error: %s",
            exc,
        )
        return {
            "status": "error",
            "message": str(exc),
        }


async def webcontainer_run_command(
    instance_id: str,
    command: str,
    args: list[str] | None = None,
) -> dict[str, Any]:
    try:
        async with _client() as client:
            response = await client.post(
                f"{WEBCONTAINER_API_URL}/v1/instances/{instance_id}/exec",
                json={
                    "command": command,
                    "args": args or [],
                },
                headers={
                    "Content-Type": "application/json",
                },
            )

        if response.status_code == 200:
            return {
                "status": "ok",
                "data": response.json(),
            }

        return {
            "status": "error",
            "http_status": response.status_code,
            "message": response.text,
        }

    except Exception as exc:
        logger.error(
            "WebContainer exec error: %s",
            exc,
        )
        return {
            "status": "error",
            "message": str(exc),
        }


def webcontainer_status() -> dict[str, Any]:
    return {
        "enabled": WEBCONTAINER_ENABLED,
        "api_url": WEBCONTAINER_API_URL,
    }


# ---------------------------------------------------------------------------
# Provider status
# ---------------------------------------------------------------------------

def provider_status() -> dict[str, Any]:
    return {
        "primary": PRIMARY_MODEL,
        "fallbacks": FALLBACK_MODELS,
        "credentials": {
            provider: bool(_get_credential(provider))
            for provider in (
                "groq",
                "cerebras",
                "openrouter",
                "gemini",
            )
        },
        "openrouter": {
            "model": OPENROUTER_MODEL,
            "fallback_model": OPENROUTER_FALLBACK_MODEL,
        },
        "webcontainer": webcontainer_status(),
    }


# ---------------------------------------------------------------------------
# Core chat
# ---------------------------------------------------------------------------

async def chat(
    messages: list[dict[str, Any]],
    model: str | None = None,
    temperature: float = 0.2,
    max_tokens: int | None = None,
    **kwargs: Any,
) -> dict[str, Any]:

    if not messages:
        raise ProviderError("messages cannot be empty")

    normalized_messages = list(messages)

    if not any(
        item.get("role") == "system"
        for item in normalized_messages
    ):
        normalized_messages.insert(
            0,
            {
                "role": "system",
                "content": TRAVELER_DEV_SYSTEM_PROMPT,
            },
        )

    models_to_try = provider_chain(model)

    if not models_to_try:
        raise ProviderError("No AI models are configured")

    errors: list[str] = []

    async with _client() as client:

        for target_model in models_to_try:
            provider = _provider_for_model(target_model)

            key = _get_credential(provider)

            if not key:
                message = (
                    f"Missing API key for provider '{provider}'"
                )

                logger.warning(
                    "Skipping %s: %s",
                    target_model,
                    message,
                )

                errors.append(message)
                continue

            clean_model = _clean_model(
                provider,
                target_model,
            )

            payload: dict[str, Any] = {
                "model": clean_model,
                "messages": normalized_messages,
                "temperature": temperature,
            }

            if max_tokens is not None:
                payload["max_tokens"] = int(max_tokens)

            # Preserve optional OpenAI-compatible parameters supplied by
            # callers, without allowing credentials or routing fields to
            # leak into the upstream payload.
            for name in (
                "top_p",
                "frequency_penalty",
                "presence_penalty",
                "stop",
            ):
                if name in kwargs and kwargs[name] is not None:
                    payload[name] = kwargs[name]

            try:
                headers = _headers(provider)

                response = await client.post(
                    _url(provider),
                    headers=headers,
                    json=payload,
                )

                if response.status_code == 200:
                    try:
                        data = response.json()
                    except ValueError as exc:
                        raise ProviderError(
                            f"{provider} returned invalid JSON"
                        ) from exc

                    result = _extract_response(
                        data,
                        target_model,
                    )

                    logger.info(
                        "Provider success: provider=%s model=%s",
                        provider,
                        target_model,
                    )

                    return result

                body = response.text[:1000]

                # Do not falsely label successful HTTP requests as errors.
                logger.warning(
                    "Provider rejected request: provider=%s model=%s "
                    "http_status=%s body=%s",
                    provider,
                    target_model,
                    response.status_code,
                    body,
                )

                errors.append(
                    f"{provider} HTTP {response.status_code}: {body}"
                )

            except httpx.TimeoutException as exc:
                logger.warning(
                    "Provider timeout: provider=%s model=%s error=%s",
                    provider,
                    target_model,
                    exc,
                )

                errors.append(
                    f"{provider} timeout"
                )

            except httpx.RequestError as exc:
                logger.warning(
                    "Provider network failure: provider=%s model=%s "
                    "error=%s",
                    provider,
                    target_model,
                    exc,
                )

                errors.append(
                    f"{provider} network error: {exc}"
                )

            except ProviderError as exc:
                logger.warning(
                    "Provider failure: provider=%s model=%s error=%s",
                    provider,
                    target_model,
                    exc,
                )

                errors.append(str(exc))

            except Exception as exc:
                logger.exception(
                    "Unexpected provider failure: provider=%s model=%s",
                    provider,
                    target_model,
                )

                errors.append(
                    f"{provider} unexpected error: {exc}"
                )

    last_error = errors[-1] if errors else "unknown provider error"

    raise ProviderError(
        f"All providers failed. Last error: {last_error}"
    )
