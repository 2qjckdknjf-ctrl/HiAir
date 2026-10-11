import os
from contextlib import contextmanager
from datetime import date
from uuid import uuid4

import pytest
from psycopg import sql
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.core.settings import settings
from app.models.health_intelligence import HealthSyncRequest
from app.services import db, health_sync_repository


def test_pool_reuses_connection_and_rolls_back_failed_transaction(monkeypatch):
    if not os.getenv('DATABASE_URL') or settings.app_env in ('production', 'staging'):
        pytest.skip('Isolated test database required')
    with ConnectionPool(settings.database_url, min_size=1, max_size=1,
                        kwargs={"row_factory":dict_row,"prepare_threshold":None}) as pool:
        monkeypatch.setattr(db, 'connection_pool', lambda: pool)
        table = sql.Identifier('pool_test_' + uuid4().hex)
        with db.get_connection() as conn:
            first = conn.execute('SELECT pg_backend_pid() AS pid').fetchone()['pid']
            conn.execute(sql.SQL('CREATE TEMP TABLE {} (n int)').format(table))
        with pytest.raises(ValueError):
            with db.get_connection() as conn:
                conn.execute(sql.SQL('INSERT INTO {} VALUES (1)').format(table))
                raise ValueError('Rollback this transaction')
        with db.get_connection() as conn:
            assert conn.execute('SELECT pg_backend_pid() AS pid').fetchone()['pid'] == first
            assert conn.execute(sql.SQL('SELECT COUNT(*) AS n FROM {}').format(table)).fetchone()['n'] == 0
            conn.execute(sql.SQL('DROP TABLE {}').format(table))


def test_sync_uses_one_transaction_and_preserves_consent_filter(monkeypatch):
    connection = object()
    borrowed = []
    written = []
    @contextmanager
    def borrow():
        borrowed.append(connection)
        yield connection
    monkeypatch.setattr(health_sync_repository, 'get_connection', borrow)
    monkeypatch.setattr(health_sync_repository, 'consent_allows_metric', lambda consent, metric: metric == 'steps')
    monkeypatch.setattr(health_sync_repository, 'upsert_metric_daily', lambda **kw: written.append(kw))
    monkeypatch.setattr(health_sync_repository, 'upsert_sync_state', lambda **kw: written.append(kw))
    payload = HealthSyncRequest(localDate=date.today(), timezone='UTC', platform='ios', source='apple_health',
        metrics=[{'metricType':'steps','unit':'count','valueTotal':3,'sampleCount':1},
                 {'metricType':'resting_heart_rate','unit':'bpm','valueAvg':60,'sampleCount':1}])
    accepted, rejected, _, _ = health_sync_repository.apply_sync('owned-user', payload, consent=object())
    assert accepted == 1
    assert rejected == ['resting_heart_rate:consent_denied']
    assert len(borrowed) == 1
    assert all(row['connection'] is connection and row['user_id'] == 'owned-user' for row in written)


def test_route_latency_metrics_are_separate(monkeypatch):
    from app.services import observability
    monkeypatch.setattr(observability, 'state', observability.ObservabilityState())
    observability.record_request('GET','/api/v1/health/insights',200,100)
    observability.record_request('GET','/api/v1/health/insights',503,300)
    observability.record_request('GET','/api/health',200,5)
    timing=observability.snapshot_metrics()['by_path_latency']
    assert timing['/api/v1/health/insights']=={'count':2,'avg_ms':200,'max_ms':300}
    assert timing['/api/health']['avg_ms']==5
