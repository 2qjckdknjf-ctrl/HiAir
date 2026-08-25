"""Work site registry prefers fresh instrument WBGT over meteo estimate."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

from app.api import work as work_api
from app.models.work_safety import WorkSiteCreateRequest, WorkSiteWbgtIngestRequest
import app.services.work_sites_repository as work_sites_repository


def setup_function() -> None:
    work_sites_repository.force_memory_store(True)
    work_sites_repository.reset_store()


def teardown_function() -> None:
    work_sites_repository.reset_store()
    work_sites_repository.force_memory_store(False)


def test_instrument_wbgt_preferred_over_meteo_estimate() -> None:
    site = work_sites_repository.create_site(
        user_id="u1",
        payload=WorkSiteCreateRequest(name="Dock", lat=25.2, lon=55.3),
    )
    now = datetime.now(timezone.utc)
    work_sites_repository.ingest_wbgt(
        user_id="u1",
        site_id=site.id,
        payload=WorkSiteWbgtIngestRequest(wbgtC=27.0, measuredAt=now.isoformat()),
    )
    instrument = work_sites_repository.latest_instrument_wbgt(user_id="u1", site_id=site.id)
    assert instrument == 27.0

    fake = MagicMock(
        feels_like=38.0,
        temperature_c=36.0,
        wbgt_c=32.0,
        wbgt_estimated=True,
        source="live",
    )
    with patch(
        "app.services.air_environment_service.resolve_environment_snapshot",
        return_value=fake,
    ):
        env, source = work_api._environment_for_site(
            site.lat,
            site.lon,
            instrument_wbgt_c=instrument,
        )
    assert env.wbgt_c == 27.0
    assert env.wbgt_estimated is False
    assert source == "instrument_wbgt"


def test_stale_instrument_wbgt_ignored() -> None:
    site = work_sites_repository.create_site(
        user_id="u1",
        payload=WorkSiteCreateRequest(name="Dock", lat=25.2, lon=55.3),
    )
    stale = (datetime.now(timezone.utc) - timedelta(hours=2)).isoformat()
    work_sites_repository.ingest_wbgt(
        user_id="u1",
        site_id=site.id,
        payload=WorkSiteWbgtIngestRequest(wbgtC=40.0, measuredAt=stale),
    )
    assert work_sites_repository.latest_instrument_wbgt(user_id="u1", site_id=site.id) is None
