"""Real isolated DB equivalence and owner-bound batching regressions."""
from datetime import UTC, date, datetime, timedelta
from uuid import uuid4
from unittest.mock import MagicMock

from app.models.wearable import WearableSource
from app.services.db import get_connection
from app.services import health_sync_repository as health, wearable_repository as wearables
from app.services import wearable_service
from scripts.init_db import main as init_db


def test_batched_load_preserves_windows_source_and_owner():
    init_db()
    owner, other = str(uuid4()), str(uuid4())
    day, now = date.today(), datetime.now(tz=UTC)
    source = WearableSource.APPLE_HEALTH
    try:
        with get_connection() as conn:
            for user in (owner, other):
                for days, hr in ((0, 60), (4, 70), (15, 80), (40, 100)):
                    conn.execute("INSERT INTO wearable_daily_summaries(user_id,date,source,steps_total,resting_heart_rate_avg) VALUES (%s,%s,'apple_health',%s,%s)",
                                 (user, day-timedelta(days=days), 1000 if user==owner else 99999, hr if user==owner else 200))
                for hours, steps in ((0.5, 10), (2, 20), (4, 30)):
                    conn.execute("INSERT INTO wearable_hourly_summaries(user_id,hour_start,source,steps_total) VALUES (%s,%s,'apple_health',%s)",
                                 (user, now-timedelta(hours=hours), steps if user==owner else 99999))
            conn.execute("INSERT INTO wearable_hourly_summaries(user_id,hour_start,source,steps_total) VALUES (%s,%s,'health_connect',99999)", (owner, now))
        batch = wearables.get_personal_load_core(owner, day, source)
        assert batch['daily'] == wearables.get_daily_summary(owner, day, source)
        assert batch['daily'].stepsTotal == 1000
        assert batch['steps_hour'] == wearables.sum_steps_since(owner, now-timedelta(hours=1), source) == 10
        assert batch['steps_3h'] == wearables.sum_steps_since(owner, now-timedelta(hours=3), source) == 30
        assert batch['hr_7d'] == wearables.resting_hr_baseline(owner, 7) == 65
        assert batch['hr_30d'] == wearables.resting_hr_baseline(owner, 30) == 70
    finally:
        with get_connection() as conn:
            for table in ('wearable_daily_summaries', 'wearable_hourly_summaries'):
                conn.execute(f'DELETE FROM {table} WHERE user_id IN (%s,%s)', (owner, other))


def test_batch_medians_match_quality_null_sparse_zero_even_rules():
    init_db()
    owner, other = str(uuid4()), str(uuid4())
    try:
        with get_connection() as conn:
            for user in (owner, other):
                for metric, count in (('odd', 5), ('even', 6), ('sparse', 4)):
                    for i in range(count):
                        conn.execute("INSERT INTO wearable_metric_daily(user_id,local_date,metric_type,unit,source_platform,value_total,quality_state) VALUES (%s,%s,%s,'count','apple_health',%s,%s)",
                                     (user, date.today()-timedelta(days=i), metric, i if user==owner else 999, 'partial' if i==0 else 'ok'))
            conn.execute("INSERT INTO wearable_metric_daily(user_id,local_date,metric_type,unit,source_platform,value_avg,quality_state) VALUES (%s,CURRENT_DATE-10,'odd','count','apple_health',999,'permission_denied')", (owner,))
            conn.execute("INSERT INTO wearable_metric_daily(user_id,local_date,metric_type,unit,source_platform,value_avg,quality_state) VALUES (%s,CURRENT_DATE-11,'odd','count','apple_health',NULL,'ok')", (owner,))
        batch = health.metric_baselines(owner)
        for metric in ('odd', 'even', 'sparse'):
            assert batch[metric] == health.metric_baseline(owner, metric)
        assert batch == {'odd': 2.0, 'even': 2.5, 'sparse': None}
        assert health.metric_baselines(str(uuid4())) == {}
    finally:
        with get_connection() as conn:
            conn.execute('DELETE FROM wearable_metric_daily WHERE user_id IN (%s,%s)', (owner, other))


def test_revoked_consent_never_reads_batched_load(monkeypatch):
    monkeypatch.setattr(wearables, 'get_active_consent', lambda user: None)
    read = MagicMock(side_effect=AssertionError('Read after revoked consent'))
    monkeypatch.setattr(wearables, 'get_personal_load_core', read)
    assert not wearable_service.build_personal_load_input('owner').consent_active
    read.assert_not_called()
