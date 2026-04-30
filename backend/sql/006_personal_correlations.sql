CREATE TABLE IF NOT EXISTS personal_correlations (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    factor_a TEXT NOT NULL,
    factor_b TEXT NOT NULL,
    coefficient DOUBLE PRECISION NOT NULL,
    p_value DOUBLE PRECISION NOT NULL,
    sample_size INT NOT NULL,
    window_days INT NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pc_profile_computed
    ON personal_correlations(profile_id, computed_at DESC);
