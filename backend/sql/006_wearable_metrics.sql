CREATE TABLE IF NOT EXISTS wearable_metrics (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    steps INTEGER,
    resting_heart_rate_bpm INTEGER,
    hrv_ms DOUBLE PRECISION,
    sleep_hours DOUBLE PRECISION,
    sleep_quality_score SMALLINT,
    source TEXT NOT NULL DEFAULT 'manual',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wearable_metrics_user_recorded
    ON wearable_metrics(user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_wearable_metrics_profile_recorded
    ON wearable_metrics(profile_id, recorded_at DESC);
