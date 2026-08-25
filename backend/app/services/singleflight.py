"""Coalesce concurrent work for the same key (one live fetch, N waiters)."""

from __future__ import annotations

import threading
from collections.abc import Callable
from concurrent.futures import Future
from typing import TypeVar

T = TypeVar("T")


class SingleFlight:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._inflight: dict[str, Future[T]] = {}

    def do(self, key: str, fn: Callable[[], T]) -> T:
        wait = False
        with self._lock:
            existing = self._inflight.get(key)
            if existing is not None:
                future = existing
                wait = True
            else:
                future = Future()
                self._inflight[key] = future
        if wait:
            return future.result()
        try:
            result = fn()
        except Exception as exc:
            future.set_exception(exc)
            raise
        else:
            future.set_result(result)
            return result
        finally:
            with self._lock:
                if self._inflight.get(key) is future:
                    del self._inflight[key]
