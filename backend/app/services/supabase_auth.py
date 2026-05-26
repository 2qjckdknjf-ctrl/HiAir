from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import jwt
from jwt import InvalidTokenError, PyJWKClient

from app.core.settings import settings


class SupabaseAuthError(ValueError):
    pass


@dataclass(frozen=True)
class SupabasePrincipal:
    user_id: str
    email: str | None
    claims: dict[str, Any]


def _clean_url(raw: str) -> str:
    return raw.rstrip("/")


def _expected_issuer() -> str | None:
    if not settings.supabase_url:
        return None
    return f"{_clean_url(settings.supabase_url)}/auth/v1"


@lru_cache(maxsize=1)
def _jwks_client() -> PyJWKClient:
    if not settings.supabase_url:
        raise SupabaseAuthError("SUPABASE_URL is not configured")
    jwks_url = f"{_clean_url(settings.supabase_url)}/auth/v1/.well-known/jwks.json"
    return PyJWKClient(jwks_url)


def _decode_with_secret(token: str) -> dict[str, Any]:
    if not settings.supabase_jwt_secret:
        raise SupabaseAuthError("SUPABASE_JWT_SECRET is not configured")
    issuer = _expected_issuer()
    kwargs: dict[str, Any] = {
        "key": settings.supabase_jwt_secret,
        "algorithms": ["HS256"],
        "options": {"verify_aud": False},
    }
    if issuer:
        kwargs["issuer"] = issuer
    return jwt.decode(token, **kwargs)


def _decode_with_jwks(token: str) -> dict[str, Any]:
    signing_key = _jwks_client().get_signing_key_from_jwt(token)
    issuer = _expected_issuer()
    kwargs: dict[str, Any] = {
        "key": signing_key.key,
        "algorithms": ["RS256", "ES256"],
        "options": {"verify_aud": False},
    }
    if issuer:
        kwargs["issuer"] = issuer
    return jwt.decode(token, **kwargs)


def verify_supabase_access_token(token: str) -> SupabasePrincipal:
    if not token:
        raise SupabaseAuthError("Missing Supabase access token")
    if not settings.supabase_url:
        raise SupabaseAuthError("SUPABASE_URL is not configured")

    claims: dict[str, Any]
    errors: list[str] = []
    for decoder in (_decode_with_secret, _decode_with_jwks):
        try:
            claims = decoder(token)
            break
        except SupabaseAuthError as exc:
            errors.append(str(exc))
        except InvalidTokenError as exc:
            errors.append(str(exc))
    else:
        raise SupabaseAuthError(f"Invalid Supabase access token: {'; '.join(errors)}")

    sub = claims.get("sub")
    if not isinstance(sub, str) or not sub:
        raise SupabaseAuthError("Supabase access token does not contain a valid sub claim")

    email_claim = claims.get("email")
    email = email_claim if isinstance(email_claim, str) and email_claim else None
    return SupabasePrincipal(user_id=sub, email=email, claims=claims)
