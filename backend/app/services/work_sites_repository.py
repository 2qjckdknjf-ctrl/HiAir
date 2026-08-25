"""Work site registry + instrument WBGT readings (memory fallback for tests)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from psycopg import OperationalError
from psycopg.errors import UndefinedTable

from app.models.work_safety import WorkSite, WorkSiteCreateRequest, WorkSiteWbgtIngestRequest
from app.services.db import get_connection

_SITES: dict[str, dict[str, WorkSite]] = {}
_READINGS: dict[str, list[dict]] = {}
_FORCE_MEMORY = False

# Instrument readings older than this are ignored for occupational assessment.
INSTRUMENT_WBGT_TTL = timedelta(minutes=30)


def reset_store() -> None:
    _SITES.clear()
    _READINGS.clear()


def force_memory_store(enabled: bool = True) -> None:
    global _FORCE_MEMORY
    _FORCE_MEMORY = enabled


def _row_to_site(row: dict) -> WorkSite:
    created = row.get("created_at")
    return WorkSite(
        id=str(row["id"]),
        userId=str(row["user_id"]),
        name=row["name"],
        lat=float(row["lat"]),
        lon=float(row["lon"]),
        timezone=row.get("timezone"),
        createdAt=created.isoformat() if hasattr(created, "isoformat") else created,
    )


def _create_memory(*, user_id: str, payload: WorkSiteCreateRequest) -> WorkSite:
    site = WorkSite(
        id=str(uuid4()),
        userId=user_id,
        name=payload.name.strip(),
        lat=payload.lat,
        lon=payload.lon,
        timezone=payload.timezone,
        createdAt=datetime.now(timezone.utc).isoformat(),
    )
    _SITES.setdefault(user_id, {})[site.id] = site
    return site


def create_site(*, user_id: str, payload: WorkSiteCreateRequest) -> WorkSite:
    if _FORCE_MEMORY:
        return _create_memory(user_id=user_id, payload=payload)

    site_id = str(uuid4())
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO work_sites (id, user_id, name, lat, lon, timezone)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id, user_id, name, lat, lon, timezone, created_at
                    """,
                    (site_id, user_id, payload.name.strip(), payload.lat, payload.lon, payload.timezone),
                )
                return _row_to_site(dict(cur.fetchone()))
    except (UndefinedTable, OperationalError):
        return _create_memory(user_id=user_id, payload=payload)


def list_sites(*, user_id: str) -> list[WorkSite]:
    if _FORCE_MEMORY:
        return sorted(_SITES.get(user_id, {}).values(), key=lambda s: s.createdAt or "", reverse=True)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, user_id, name, lat, lon, timezone, created_at
                    FROM work_sites
                    WHERE user_id = %s
                    ORDER BY created_at DESC
                    """,
                    (user_id,),
                )
                return [_row_to_site(dict(row)) for row in cur.fetchall()]
    except (UndefinedTable, OperationalError):
        return sorted(_SITES.get(user_id, {}).values(), key=lambda s: s.createdAt or "", reverse=True)


def get_site(*, user_id: str, site_id: str) -> WorkSite | None:
    if _FORCE_MEMORY:
        return _SITES.get(user_id, {}).get(site_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, user_id, name, lat, lon, timezone, created_at
                    FROM work_sites
                    WHERE user_id = %s AND id = %s
                    """,
                    (user_id, site_id),
                )
                row = cur.fetchone()
                return _row_to_site(dict(row)) if row else None
    except (UndefinedTable, OperationalError):
        return _SITES.get(user_id, {}).get(site_id)


def delete_site(*, user_id: str, site_id: str) -> bool:
    if _FORCE_MEMORY:
        user_sites = _SITES.get(user_id)
        if not user_sites or site_id not in user_sites:
            return False
        del user_sites[site_id]
        _READINGS.pop(site_id, None)
        return True
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM work_sites WHERE user_id = %s AND id = %s",
                    (user_id, site_id),
                )
                return cur.rowcount > 0
    except (UndefinedTable, OperationalError):
        user_sites = _SITES.get(user_id)
        if not user_sites or site_id not in user_sites:
            return False
        del user_sites[site_id]
        _READINGS.pop(site_id, None)
        return True


def ingest_wbgt(*, user_id: str, site_id: str, payload: WorkSiteWbgtIngestRequest) -> dict:
    site = get_site(user_id=user_id, site_id=site_id)
    if site is None:
        raise ValueError("Work site not found")
    measured_at = datetime.fromisoformat(payload.measuredAt.replace("Z", "+00:00"))
    if measured_at.tzinfo is None:
        measured_at = measured_at.replace(tzinfo=timezone.utc)

    reading = {
        "id": str(uuid4()),
        "site_id": site_id,
        "user_id": user_id,
        "wbgt_c": float(payload.wbgtC),
        "measured_at": measured_at,
        "source": payload.source or "instrument",
    }

    if _FORCE_MEMORY:
        _READINGS.setdefault(site_id, []).append(reading)
        return reading

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO work_site_wbgt_readings
                        (id, site_id, user_id, wbgt_c, measured_at, source)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id, site_id, user_id, wbgt_c, measured_at, source
                    """,
                    (
                        reading["id"],
                        site_id,
                        user_id,
                        reading["wbgt_c"],
                        measured_at,
                        reading["source"],
                    ),
                )
                return dict(cur.fetchone())
    except (UndefinedTable, OperationalError):
        _READINGS.setdefault(site_id, []).append(reading)
        return reading


def latest_instrument_wbgt(*, user_id: str, site_id: str, now: datetime | None = None) -> float | None:
    site = get_site(user_id=user_id, site_id=site_id)
    if site is None:
        return None
    now = now or datetime.now(timezone.utc)
    cutoff = now - INSTRUMENT_WBGT_TTL

    if _FORCE_MEMORY:
        readings = _READINGS.get(site_id, [])
        fresh = [r for r in readings if r["measured_at"] >= cutoff]
        if not fresh:
            return None
        latest = max(fresh, key=lambda r: r["measured_at"])
        return float(latest["wbgt_c"])

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT wbgt_c
                    FROM work_site_wbgt_readings
                    WHERE site_id = %s AND user_id = %s AND measured_at >= %s
                    ORDER BY measured_at DESC
                    LIMIT 1
                    """,
                    (site_id, user_id, cutoff),
                )
                row = cur.fetchone()
                return float(row["wbgt_c"]) if row else None
    except (UndefinedTable, OperationalError):
        readings = _READINGS.get(site_id, [])
        fresh = [r for r in readings if r["measured_at"] >= cutoff]
        if not fresh:
            return None
        latest = max(fresh, key=lambda r: r["measured_at"])
        return float(latest["wbgt_c"])
