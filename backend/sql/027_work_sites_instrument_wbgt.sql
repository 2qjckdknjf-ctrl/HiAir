-- HiAir 2.0 — B2B work site registry + instrument WBGT readings (additive)

CREATE TABLE IF NOT EXISTS work_sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    timezone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT work_sites_lat_check CHECK (lat >= -90 AND lat <= 90),
    CONSTRAINT work_sites_lon_check CHECK (lon >= -180 AND lon <= 180)
);

CREATE INDEX IF NOT EXISTS idx_work_sites_user_created
    ON work_sites (user_id, created_at DESC);

ALTER TABLE work_sites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS work_sites_owner_select ON work_sites;
CREATE POLICY work_sites_owner_select ON work_sites
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_sites_owner_insert ON work_sites;
CREATE POLICY work_sites_owner_insert ON work_sites
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_sites_owner_delete ON work_sites;
CREATE POLICY work_sites_owner_delete ON work_sites
    FOR DELETE
    USING (auth.uid()::text = user_id);

CREATE TABLE IF NOT EXISTS work_site_wbgt_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES work_sites(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    wbgt_c DOUBLE PRECISION NOT NULL,
    measured_at TIMESTAMPTZ NOT NULL,
    source TEXT NOT NULL DEFAULT 'instrument',
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT work_site_wbgt_readings_wbgt_check CHECK (wbgt_c >= -50 AND wbgt_c <= 60)
);

CREATE INDEX IF NOT EXISTS idx_work_site_wbgt_site_measured
    ON work_site_wbgt_readings (site_id, measured_at DESC);

ALTER TABLE work_site_wbgt_readings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS work_site_wbgt_owner_select ON work_site_wbgt_readings;
CREATE POLICY work_site_wbgt_owner_select ON work_site_wbgt_readings
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_site_wbgt_owner_insert ON work_site_wbgt_readings;
CREATE POLICY work_site_wbgt_owner_insert ON work_site_wbgt_readings
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);
