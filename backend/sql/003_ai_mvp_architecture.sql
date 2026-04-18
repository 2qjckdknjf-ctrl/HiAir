ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS profile_type TEXT,
    ADD COLUMN IF NOT EXISTS age_group TEXT NOT NULL DEFAULT 'adult',
    ADD COLUMN IF NOT EXISTS heat_sensitivity_level SMALLINT NOT NULL DEFAULT 2,
    ADD COLUMN IF NOT EXISTS respiratory_sensitivity_level SMALLINT NOT NULL DEFAULT 2,
    ADD COLUMN IF NOT EXISTS activity_level TEXT NOT NULL DEFAULT 'moderate',
    ADD COLUMN IF NOT EXISTS location_name TEXT,
    ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE profiles
SET profile_type = CASE persona_type
    WHEN 'adult' THEN 'adult_default'
    WHEN 'child' THEN 'child'
    WHEN 'elderly' THEN 'elderly'
    WHEN 'asthma' THEN 'asthma_sensitive'
    WHEN 'allergy' THEN 'allergy_sensitive'
    WHEN 'runner' THEN 'runner'
    WHEN 'worker' THEN 'outdoor_worker'
    ELSE 'adult_default'
END
WHERE profile_type IS NULL;

ALTER TABLE profiles
    ALTER COLUMN profile_type SET DEFAULT 'adult_default';

ALTER TABLE profiles
    ALTER COLUMN profile_type SET NOT NULL;

ALTER TABLE environment_snapshots
    ADD COLUMN IF NOT EXISTS geo_hash TEXT,
    ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS lon DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS feels_like DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS pm10 DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS uv DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS wind_speed DOUBLE PRECISION;

CREATE TABLE IF NOT EXISTS risk_assessments (
    id UUID PRIMARY KEY,
    user_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    environmental_snapshot_id UUID REFERENCES environment_snapshots(id) ON DELETE SET NULL,
    overall_risk TEXT NOT NULL,
    heat_risk TEXT NOT NULL,
    air_risk TEXT NOT NULL,
    outdoor_risk TEXT NOT NULL,
    ventilation_risk TEXT NOT NULL,
    safe_windows_json JSONB NOT NULL,
    reason_codes_json JSONB NOT NULL,
    recommendation_flags_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_recommendations (
    id UUID PRIMARY KEY,
    risk_assessment_id UUID NOT NULL REFERENCES risk_assessments(id) ON DELETE CASCADE,
    headline TEXT NOT NULL,
    summary TEXT NOT NULL,
    actions_json JSONB NOT NULL,
    model_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS alert_events (
    id UUID PRIMARY KEY,
    user_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    dedupe_key TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivery_status TEXT NOT NULL DEFAULT 'queued'
);

ALTER TABLE symptom_logs
    ADD COLUMN IF NOT EXISTS symptom_type TEXT,
    ADD COLUMN IF NOT EXISTS intensity SMALLINT,
    ADD COLUMN IF NOT EXISTS note TEXT,
    ADD COLUMN IF NOT EXISTS logged_at TIMESTAMPTZ;

UPDATE symptom_logs
SET logged_at = timestamp_utc
WHERE logged_at IS NULL;

ALTER TABLE symptom_logs
    ALTER COLUMN logged_at SET DEFAULT NOW();

ALTER TABLE user_settings
    ADD COLUMN IF NOT EXISTS quiet_hours_start SMALLINT NOT NULL DEFAULT 22,
    ADD COLUMN IF NOT EXISTS quiet_hours_end SMALLINT NOT NULL DEFAULT 7,
    ADD COLUMN IF NOT EXISTS profile_based_alerting BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_profiles_profile_type ON profiles(profile_type);
CREATE INDEX IF NOT EXISTS idx_environment_snapshots_lat_lon_time ON environment_snapshots(lat, lon, timestamp_utc DESC);
CREATE INDEX IF NOT EXISTS idx_risk_assessments_profile_created ON risk_assessments(user_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_recommendations_risk_assessment ON ai_recommendations(risk_assessment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alert_events_profile_sent ON alert_events(user_profile_id, sent_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_alert_events_dedupe_key ON alert_events(dedupe_key);
CREATE INDEX IF NOT EXISTS idx_symptom_logs_profile_logged_at ON symptom_logs(profile_id, logged_at DESC);
