from collections import defaultdict, deque
from datetime import UTC, datetime, timedelta


_REQUEST_HISTORY: dict[str, deque[datetime]] = defaultdict(deque)


def check_limit(key: str, limit: int, window_seconds: int) -> bool:
    now = datetime.now(tz=UTC)
    history = _REQUEST_HISTORY[key]
    cutoff = now - timedelta(seconds=window_seconds)
    while history and history[0] < cutoff:
        history.popleft()
    if len(history) >= limit:
        return False
    history.append(now)
    return True


def reset_for_tests() -> None:
    _REQUEST_HISTORY.clear()
