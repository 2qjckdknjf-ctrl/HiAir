-- CI/local databases may skip 018 (auth.users FK + RLS) when the auth schema
-- is absent. Soft-delete and expanded symptom columns must still exist so
-- insights/personal-patterns queries stay compatible.
-- Idempotent on production where 018 already applied these columns.

ALTER TABLE IF EXISTS public.symptom_logs
    ADD COLUMN IF NOT EXISTS category text,
    ADD COLUMN IF NOT EXISTS severity smallint,
    ADD COLUMN IF NOT EXISTS onset_at timestamptz,
    ADD COLUMN IF NOT EXISTS duration_minutes integer,
    ADD COLUMN IF NOT EXISTS ongoing boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS frequency text,
    ADD COLUMN IF NOT EXISTS body_context text,
    ADD COLUMN IF NOT EXISTS suspected_trigger text,
    ADD COLUMN IF NOT EXISTS activity_at_onset text,
    ADD COLUMN IF NOT EXISTS location_context text,
    ADD COLUMN IF NOT EXISTS hydration_state text,
    ADD COLUMN IF NOT EXISTS medication_taken boolean,
    ADD COLUMN IF NOT EXISTS timezone text,
    ADD COLUMN IF NOT EXISTS environment_snapshot_id uuid,
    ADD COLUMN IF NOT EXISTS is_custom boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS custom_label text,
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_symptom_logs_profile_type_logged
    ON public.symptom_logs (profile_id, symptom_type, logged_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_symptom_logs_profile_category
    ON public.symptom_logs (profile_id, category, logged_at DESC)
    WHERE deleted_at IS NULL;
