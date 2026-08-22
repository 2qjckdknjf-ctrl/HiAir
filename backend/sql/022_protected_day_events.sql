-- HiAir 1.6 protected-day structured events (wellness-only, no causation)
-- Table DDL is CI-compatible; RLS policies live in 025_supabase_table_rls.sql.

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
