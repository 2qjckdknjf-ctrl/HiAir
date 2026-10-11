"""A verified old renewal cannot roll back a later Apple renewal; revoke still wins."""
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.models.subscription import VerifiedStorePurchase
from app.services.db import get_connection
from app.services.subscription_repository import apply_verified_purchase
from app.services.privacy_repository import delete_user_data
from scripts.init_db import main as init_db


def test_older_apple_renewal_keeps_latest_but_refund_revokes(monkeypatch):
    # This DB regression must use real entitlements, not the API unit-suite's
    # autouse Premium fixture.
    monkeypatch.undo()
    init_db()
    owner = str(uuid4())
    original = 'test-chain-' + str(uuid4())
    now = datetime.now(tz=UTC)
    def purchase(transaction, expiry, status='active'):
        return VerifiedStorePurchase(platform='ios', provider='apple', product_id='com.hiair.premium.monthly',
            plan_id='premium_monthly', status=status, transaction_id=original+transaction,
            original_transaction_id=original, expires_at=expiry)
    try:
        with get_connection() as conn:
            conn.execute("INSERT INTO users(id,email,password_hash) VALUES (%s,%s,'test-only')", (owner, owner+'@example.test'))
        latest = apply_verified_purchase(owner, purchase('-latest', now+timedelta(days=30)))
        assert latest.entitlement.is_premium
        older = apply_verified_purchase(owner, purchase('-old', now-timedelta(days=1), 'expired'))
        assert older.entitlement.is_premium
        assert older.entitlement.premium_until == latest.entitlement.premium_until
        with get_connection() as conn:
            row = conn.execute('SELECT latest_transaction_id FROM user_subscriptions WHERE user_id=%s', (owner,)).fetchone()
            assert row['latest_transaction_id'] == original+'-latest'
            assert conn.execute('SELECT COUNT(*) AS n FROM provider_transactions WHERE user_id=%s', (owner,)).fetchone()['n']==2
        refunded = apply_verified_purchase(owner, purchase('-old', now-timedelta(days=1), 'refunded'))
        assert not refunded.entitlement.is_premium
    finally:
        delete_user_data(owner)
