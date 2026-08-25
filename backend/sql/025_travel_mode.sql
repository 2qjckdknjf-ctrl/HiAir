-- HiAir 1.5 travel mode: temporary location override via saved place.

ALTER TABLE IF EXISTS user_settings
    ADD COLUMN IF NOT EXISTS travel_place_id TEXT,
    ADD COLUMN IF NOT EXISTS travel_until TIMESTAMPTZ;

COMMENT ON COLUMN user_settings.travel_place_id IS
    'Saved place id used as temporary location while travel mode is active';
COMMENT ON COLUMN user_settings.travel_until IS
    'Optional expiry for travel mode; NULL means until explicitly cleared';
