CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    persona_type TEXT NOT NULL,
    sensitivity_level TEXT NOT NULL,
    home_lat DOUBLE PRECISION NOT NULL,
    home_lon DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS environment_snapshots (
    id UUID PRIMARY KEY,
    region_key TEXT NOT NULL,
    timestamp_utc TIMESTAMPTZ NOT NULL,
    temperature_c DOUBLE PRECISION NOT NULL,
    humidity_percent DOUBLE PRECISION NOT NULL,
    aqi INTEGER NOT NULL,
    pm25 DOUBLE PRECISION NOT NULL,
    ozone DOUBLE PRECISION NOT NULL,
    source TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS symptom_logs (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    timestamp_utc TIMESTAMPTZ NOT NULL,
    cough BOOLEAN NOT NULL DEFAULT FALSE,
    wheeze BOOLEAN NOT NULL DEFAULT FALSE,
    headache BOOLEAN NOT NULL DEFAULT FALSE,
    fatigue BOOLEAN NOT NULL DEFAULT FALSE,
    sleep_quality SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_scores (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    snapshot_id UUID REFERENCES environment_snapshots(id) ON DELETE SET NULL,
    score_value INTEGER NOT NULL,
    risk_level TEXT NOT NULL,
    recommendations_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_events (
    id UUID PRIMARY KEY,
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    risk_level TEXT NOT NULL,
    should_send BOOLEAN NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    push_alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    alert_threshold TEXT NOT NULL DEFAULT 'high',
    default_persona TEXT NOT NULL DEFAULT 'adult',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    platform TEXT NOT NULL,
    device_token TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (platform, device_token)
);

CREATE TABLE IF NOT EXISTS notification_delivery_attempts (
    id UUID PRIMARY KEY,
    event_id UUID REFERENCES notification_events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    platform TEXT NOT NULL,
    device_token TEXT NOT NULL,
    provider_mode TEXT NOT NULL,
    attempt_no INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    status_code INTEGER,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE notification_delivery_attempts
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'canceled', 'trialing')),
    starts_at TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    provider_subscription_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscription_webhook_events (
    id UUID PRIMARY KEY,
    provider TEXT NOT NULL,
    event_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    provider_subscription_id TEXT NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, event_id)
);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_symptom_logs_profile_id ON symptom_logs(profile_id);
CREATE INDEX IF NOT EXISTS idx_risk_scores_profile_id ON risk_scores(profile_id);
CREATE INDEX IF NOT EXISTS idx_env_region_time ON environment_snapshots(region_key, timestamp_utc DESC);
CREATE INDEX IF NOT EXISTS idx_notification_events_profile_id ON notification_events(profile_id);
CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_id ON push_device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_device_tokens_profile_id ON push_device_tokens(profile_id);
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_event_id ON notification_delivery_attempts(event_id);
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_user_id ON notification_delivery_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_period_end ON user_subscriptions(current_period_end);
CREATE INDEX IF NOT EXISTS idx_subscription_webhook_events_provider_received
    ON subscription_webhook_events(provider, received_at DESC);

CREATE TABLE IF NOT EXISTS notification_secret_rotation_events (
    id UUID PRIMARY KEY,
    provider TEXT NOT NULL,
    key_ref TEXT,
    rotated_by TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_secret_rotation_provider_time
    ON notification_secret_rotation_events(provider, created_at DESC);
