from collections import defaultdict, deque
from datetime import UTC, datetime, timedelta


_ATTEMPTS: dict[str, deque[datetime]] = defaultdict(deque)
_LOCKED_UNTIL: dict[str, datetime] = {}


def is_rate_limited(key: str, limit: int, window_seconds: int) -> bool:
    now = datetime.now(tz=UTC)
    history = _ATTEMPTS[key]
    cutoff = now - timedelta(seconds=window_seconds)
    while history and history[0] < cutoff:
        history.popleft()
    if len(history) >= limit:
        return True
    history.append(now)
    return False


def check_login_lock(email: str) -> bool:
    now = datetime.now(tz=UTC)
    until = _LOCKED_UNTIL.get(email.lower())
    if until is None:
        return False
    if until <= now:
        _LOCKED_UNTIL.pop(email.lower(), None)
        return False
    return True


def register_login_failure(email: str) -> None:
    key = f"login-fail:{email.lower()}"
    if is_rate_limited(key=key, limit=5, window_seconds=900):
        _LOCKED_UNTIL[email.lower()] = datetime.now(tz=UTC) + timedelta(minutes=15)


def clear_login_failures(email: str) -> None:
    key = f"login-fail:{email.lower()}"
    _ATTEMPTS.pop(key, None)
    _LOCKED_UNTIL.pop(email.lower(), None)


def reset_state_for_tests() -> None:
    _ATTEMPTS.clear()
    _LOCKED_UNTIL.clear()
