-- HiAir 1.3 / 2.0: persist CAMS pollen, wildfire smoke, and meteo WBGT on
-- environment_snapshots so the geo cache cannot silently drop honesty fields.

ALTER TABLE IF EXISTS environment_snapshots
    ADD COLUMN IF NOT EXISTS pollen_grains_m3 DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS wildfire_pm10 DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS wbgt_c DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS wbgt_estimated BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS shortwave_wm2 DOUBLE PRECISION;

COMMENT ON COLUMN environment_snapshots.pollen_grains_m3 IS
    'Max CAMS / Open-Meteo pollen grains/m³ when available; NULL outside coverage';
COMMENT ON COLUMN environment_snapshots.wildfire_pm10 IS
    'Open-Meteo pm10_wildfires µg/m³ when available; NULL outside coverage';
COMMENT ON COLUMN environment_snapshots.wbgt_c IS
    'Outdoor WBGT °C (instrument or meteo estimate)';
COMMENT ON COLUMN environment_snapshots.wbgt_estimated IS
    'TRUE when wbgt_c is meteo-estimated, never instrument WBGT';
COMMENT ON COLUMN environment_snapshots.shortwave_wm2 IS
    'Shortwave radiation W/m² used for meteo WBGT estimate';
