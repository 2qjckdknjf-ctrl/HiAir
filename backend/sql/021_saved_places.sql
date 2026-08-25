-- HiAir 1.5 saved places (coordinates only, no forecast synthesis)
-- Table DDL is CI-compatible; RLS policies live in 025_supabase_table_rls.sql.

CREATE TABLE IF NOT EXISTS saved_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    place_type TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    timezone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT saved_places_place_type_check
        CHECK (place_type IN ('home', 'work', 'school', 'parents', 'vacation', 'other')),
    CONSTRAINT saved_places_lat_check CHECK (lat >= -90 AND lat <= 90),
    CONSTRAINT saved_places_lon_check CHECK (lon >= -180 AND lon <= 180)
);

CREATE INDEX IF NOT EXISTS idx_saved_places_user_created
    ON saved_places (user_id, created_at DESC);
