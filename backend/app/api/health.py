from datetime import datetime, timezone
import os

from app.services.source_identity import application_source_digest

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    payload: dict[str, str] = {
        "status": "ok",
        "service": "hiair-backend",
        "app_source_sha256": application_source_digest(),
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
    }
    deploy_sha = os.getenv("DEPLOY_GIT_SHA", "").strip()
    if deploy_sha:
        payload["deploy_git_sha"] = deploy_sha
    return payload
