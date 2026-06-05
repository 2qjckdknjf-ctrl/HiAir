-- Profile date of birth for age-aware risk and analytics.

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS date_of_birth DATE;

CREATE INDEX IF NOT EXISTS idx_profiles_date_of_birth ON profiles (date_of_birth)
    WHERE date_of_birth IS NOT NULL;
