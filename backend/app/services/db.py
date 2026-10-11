from collections.abc import Iterator
from contextlib import contextmanager
import atexit
import os
from threading import Lock

from psycopg import Connection
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.core.settings import settings

_pool: ConnectionPool | None = None
_pool_key: tuple[int, str] | None = None
_pool_lock = Lock()


def connection_pool() -> ConnectionPool:
    """Bound process-local connections; preserve transaction boundaries per repository call."""
    global _pool, _pool_key
    key = (os.getpid(), settings.database_url)
    with _pool_lock:
        if _pool is None or _pool_key != key:
            if _pool is not None:
                _pool.close()
            _pool = ConnectionPool(
                settings.database_url,
                min_size=1, max_size=8, timeout=5, max_waiting=32,
                kwargs={"row_factory": dict_row, "connect_timeout": 5, "prepare_threshold": None},
                open=False,
            )
            _pool.open()
            _pool_key = key
        return _pool


def close_connection_pool() -> None:
    global _pool, _pool_key
    with _pool_lock:
        if _pool is not None:
            _pool.close()
        _pool = None
        _pool_key = None


atexit.register(close_connection_pool)


@contextmanager
def get_connection() -> Iterator[Connection]:
    # Pool context commits on success, rolls back on failure, and replaces broken
    # connections. Never cache user results or bypass repository ownership checks.
    with connection_pool().connection() as conn:
        yield conn
