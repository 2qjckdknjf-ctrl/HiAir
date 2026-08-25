"""Concurrent callers share one in-flight result."""

from __future__ import annotations

import threading
import time

from app.services.singleflight import SingleFlight


def test_singleflight_coalesces_concurrent_calls() -> None:
    flight = SingleFlight()
    calls = 0
    hold = threading.Event()
    results: list[str | None] = [None, None]

    def work() -> str:
        nonlocal calls
        calls += 1
        hold.wait(timeout=2)
        return "ok"

    def run(index: int) -> None:
        results[index] = flight.do("geo", work)

    first = threading.Thread(target=run, args=(0,))
    first.start()
    deadline = time.time() + 1
    while calls == 0 and time.time() < deadline:
        time.sleep(0.005)
    second = threading.Thread(target=run, args=(1,))
    second.start()
    time.sleep(0.05)
    hold.set()
    first.join(timeout=2)
    second.join(timeout=2)
    assert calls == 1
    assert results == ["ok", "ok"]


def test_singleflight_reruns_after_completion() -> None:
    flight = SingleFlight()
    calls = 0

    def work() -> int:
        nonlocal calls
        calls += 1
        return calls

    assert flight.do("k", work) == 1
    assert flight.do("k", work) == 2
    assert calls == 2
