import secrets
from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPBearer, HTTPAuthorizationCredentials
from .config import GATEWAY_API_KEY

api_key_header = APIKeyHeader(
    name="X-API-Key",
    auto_error=False
)

bearer = HTTPBearer(auto_error=False)

async def require_api_key(
    header_key: str | None = Security(api_key_header),
    credentials: HTTPAuthorizationCredentials | None = Security(bearer),
):
    expected = GATEWAY_API_KEY

    if not expected:
        raise HTTPException(
            status_code=503,
            detail="GATEWAY_API_KEY is not configured."
        )

    supplied = header_key or (
        credentials.credentials if credentials else None
    )

    if not supplied or not secrets.compare_digest(supplied, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key."
        )

    return supplied
