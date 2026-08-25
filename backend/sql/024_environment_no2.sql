-- HiAir 1.3: persist provider NO2 when available (Open-Meteo nitrogen_dioxide).

ALTER TABLE IF EXISTS environment_snapshots
    ADD COLUMN IF NOT EXISTS no2 DOUBLE PRECISION;
