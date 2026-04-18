from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.models.user import AuthResponse, LoginRequest, SignupRequest
from app.services.security import create_access_token
import app.services.user_repository as user_repository
from app.api.deps import get_current_user_id

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=AuthResponse)
def signup(payload: SignupRequest) -> AuthResponse:
    try:
        user_id = user_repository.create_user(email=payload.email, password=payload.password)
    except user_repository.UserConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthResponse(user_id=user_id, access_token=create_access_token(user_id))


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest) -> AuthResponse:
    try:
        user_id = user_repository.verify_user(email=payload.email, password=payload.password)
    except user_repository.AuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthResponse(user_id=user_id, access_token=create_access_token(user_id))


@router.get("/me", response_model=dict[str, str])
def me(user_id: str = Depends(get_current_user_id)) -> dict[str, str]:
    return {"user_id": user_id}
