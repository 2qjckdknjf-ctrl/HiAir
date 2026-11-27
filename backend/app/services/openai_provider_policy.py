"""Approved final-inference provider allowlist for LLM explanations."""

from __future__ import annotations

from urllib.parse import urlparse

# Primary-source OpenAI Chat Completions HTTPS endpoints only.
# Additional hosts require an explicit product decision + privacy review.
APPROVED_OPENAI_BASE_URL_HOSTS = frozenset(
    {
        "api.openai.com",
    }
)


def normalize_openai_base_url(url: str) -> str:
    return (url or "").strip()


def openai_base_url_host(url: str) -> str:
    parsed = urlparse(normalize_openai_base_url(url))
    return (parsed.hostname or "").lower()


def is_approved_openai_base_url(url: str) -> bool:
    host = openai_base_url_host(url)
    if not host:
        return False
    return host in APPROVED_OPENAI_BASE_URL_HOSTS


def assert_approved_openai_base_url(url: str) -> str:
    normalized = normalize_openai_base_url(url)
    if not is_approved_openai_base_url(normalized):
        raise ValueError(
            "OPENAI_BASE_URL host is not on the approved inference allowlist "
            f"(got host={openai_base_url_host(normalized)!r})"
        )
    return normalized
