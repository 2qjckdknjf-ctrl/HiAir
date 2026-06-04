-- Mobile store subscriptions: entitlements and provider transaction audit trail.

CREATE TABLE IF NOT EXISTS subscription_plans (
    plan_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    billing_cycle TEXT NOT NULL CHECK (billing_cycle IN ('monthly', 'yearly')),
    ios_product_id TEXT,
    android_product_id TEXT,
    is_premium BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO subscription_plans (plan_id, name, billing_cycle, ios_product_id, android_product_id, is_premium)
VALUES
    ('premium_monthly', 'HiAir Premium Monthly', 'monthly', 'com.hiair.premium.monthly', 'hiair_premium_monthly', TRUE),
    ('premium_yearly', 'HiAir Premium Yearly', 'yearly', 'com.hiair.premium.yearly', 'hiair_premium_yearly', TRUE),
    ('basic_monthly', 'HiAir Basic Monthly (legacy stub)', 'monthly', NULL, NULL, TRUE),
    ('basic_yearly', 'HiAir Basic Yearly (legacy stub)', 'yearly', NULL, NULL, TRUE)
ON CONFLICT (plan_id) DO NOTHING;

ALTER TABLE user_subscriptions
    ADD COLUMN IF NOT EXISTS platform TEXT,
    ADD COLUMN IF NOT EXISTS provider TEXT,
    ADD COLUMN IF NOT EXISTS product_id TEXT,
    ADD COLUMN IF NOT EXISTS canceled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS original_transaction_id TEXT,
    ADD COLUMN IF NOT EXISTS purchase_token TEXT,
    ADD COLUMN IF NOT EXISTS latest_transaction_id TEXT,
    ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;

-- Widen status check for store lifecycle states (keep legacy values).
ALTER TABLE user_subscriptions DROP CONSTRAINT IF EXISTS user_subscriptions_status_check;
ALTER TABLE user_subscriptions
    ADD CONSTRAINT user_subscriptions_status_check CHECK (
        status IN (
            'active', 'inactive', 'canceled', 'trialing',
            'grace_period', 'expired', 'refunded', 'unknown'
        )
    );

CREATE TABLE IF NOT EXISTS user_entitlements (
    user_id UUID PRIMARY KEY,
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    premium_until TIMESTAMPTZ,
    source_subscription_id UUID REFERENCES user_subscriptions(id) ON DELETE SET NULL,
    max_profiles INTEGER NOT NULL DEFAULT 1,
    extended_forecast_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    custom_alerts_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    export_reports_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    advanced_insights_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    wearable_insights_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    priority_notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS provider_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web', 'manual', 'stub')),
    provider TEXT NOT NULL,
    product_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT,
    purchase_token TEXT,
    status TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    raw_payload JSONB,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_provider_transactions_user_id ON provider_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_entitlements_premium_until ON user_entitlements(premium_until);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_platform ON user_subscriptions(platform);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_product_id ON user_subscriptions(product_id);
