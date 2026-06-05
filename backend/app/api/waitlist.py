import re
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from psycopg import connect

from app.core.settings import settings

router = APIRouter(tags=["waitlist"])

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

ALLOWED_PERSONAS = {
    "parent",
    "asthma_allergy",
    "runner",
    "elderly_care",
    "outdoor_worker",
    "health_conscious",
    "other",
}


class WaitlistSignupRequest(BaseModel):
    email: EmailStr
    persona: str | None = Field(default=None, max_length=64)


class WaitlistSignupResponse(BaseModel):
    status: str
    message: str
    timestamp_utc: str


@router.post("/waitlist", response_model=WaitlistSignupResponse)
def join_waitlist(payload: WaitlistSignupRequest) -> WaitlistSignupResponse:
    email = payload.email.strip().lower()
    if not _EMAIL_RE.match(email):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid email address.",
        )

    persona = payload.persona.strip().lower() if payload.persona else None
    if persona and persona not in ALLOWED_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid persona selection.",
        )

    try:
        with connect(settings.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO waitlist_signups (email, persona, source)
                    VALUES (%s, %s, 'landing')
                    ON CONFLICT (email) DO UPDATE
                    SET persona = COALESCE(EXCLUDED.persona, waitlist_signups.persona),
                        created_at = NOW()
                    RETURNING id
                    """,
                    (email, persona),
                )
                cur.fetchone()
            conn.commit()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Waitlist is temporarily unavailable. Please try again shortly.",
        ) from exc

    return WaitlistSignupResponse(
        status="ok",
        message="You're on the list. We'll email you when early access opens.",
        timestamp_utc=datetime.now(timezone.utc).isoformat(),
    )
