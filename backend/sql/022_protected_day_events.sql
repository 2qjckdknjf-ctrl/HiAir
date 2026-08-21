-- HiAir 1.6 protected-day structured events (wellness-only, no causation)

CREATE TABLE IF NOT EXISTS protected_day_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT protected_day_events_type_check
        CHECK (event_type IN (
            'high_risk_period_avoided',
            'workout_moved',
            'ventilation_window_used',
            'poor_air_exposure_reduced'
        ))
);

CREATE INDEX IF NOT EXISTS idx_protected_day_events_profile_date
    ON protected_day_events (profile_id, event_date DESC);

ALTER TABLE protected_day_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS protected_day_events_owner_select ON protected_day_events;
CREATE POLICY protected_day_events_owner_select ON protected_day_events
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS protected_day_events_owner_insert ON protected_day_events;
CREATE POLICY protected_day_events_owner_insert ON protected_day_events
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);
