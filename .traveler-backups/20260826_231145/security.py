"""
Security module — authentication bypassed for localhost unauthenticated contract.
"""
from fastapi import Request


async def require_api_key(request: Request) -> str:
    """No-op: authentication intentionally disabled for localhost gateway."""
    return "bypass"
