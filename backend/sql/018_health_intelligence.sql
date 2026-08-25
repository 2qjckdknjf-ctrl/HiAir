-- Health Intelligence Expansion (portable DDL for CI/local PostgreSQL).
-- Supabase FK + RLS: 028_wearable_health_supabase.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE IF EXISTS public.health_data_consents
    ADD COLUMN IF NOT EXISTS activity_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS sleep_stages_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS respiratory_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS temperature_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS workouts_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS fitness_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS body_metrics_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS sensitive_metrics_enabled boolean NOT NULL DEFAULT false;

UPDATE public.health_data_consents
SET activity_enabled = TRUE
WHERE steps_enabled = TRUE
  AND activity_enabled = FALSE;

CREATE TABLE IF NOT EXISTS public.wearable_metric_daily (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    local_date date NOT NULL,
    timezone text NOT NULL DEFAULT 'UTC',
    metric_type text NOT NULL,
    value_avg numeric,
    value_min numeric,
    value_max numeric,
    value_latest numeric,
    value_total numeric,
    unit text NOT NULL,
    sample_count integer NOT NULL DEFAULT 0,
    source_platform text NOT NULL CHECK (source_platform IN ('apple_health', 'health_connect')),
    source_device_class text,
    quality_state text NOT NULL DEFAULT 'ok'
        CHECK (quality_state IN (
            'ok', 'partial', 'no_records', 'permission_unknown',
            'permission_denied', 'source_unavailable', 'stale', 'sync_error', 'unsupported'
        )),
    hrv_method text CHECK (hrv_method IS NULL OR hrv_method IN ('sdnn', 'rmssd')),
    period_start timestamptz,
    period_end timestamptz,
    synced_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, local_date, metric_type, source_platform)
);

CREATE INDEX IF NOT EXISTS idx_wearable_metric_daily_user_date
    ON public.wearable_metric_daily (user_id, local_date DESC);
CREATE INDEX IF NOT EXISTS idx_wearable_metric_daily_user_metric
    ON public.wearable_metric_daily (user_id, metric_type, local_date DESC);
CREATE INDEX IF NOT EXISTS idx_wearable_metric_daily_profile_date
    ON public.wearable_metric_daily (profile_id, local_date DESC);

CREATE TABLE IF NOT EXISTS public.wearable_sleep_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    local_date date NOT NULL,
    timezone text NOT NULL DEFAULT 'UTC',
    total_minutes integer,
    in_bed_minutes integer,
    awake_minutes integer,
    core_light_minutes integer,
    deep_minutes integer,
    rem_minutes integer,
    sleep_start timestamptz,
    sleep_end timestamptz,
    source_platform text NOT NULL CHECK (source_platform IN ('apple_health', 'health_connect')),
    quality_state text NOT NULL DEFAULT 'ok',
    synced_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, local_date, source_platform)
);

CREATE INDEX IF NOT EXISTS idx_wearable_sleep_user_date
    ON public.wearable_sleep_summaries (user_id, local_date DESC);

CREATE TABLE IF NOT EXISTS public.wearable_sync_state (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    platform text NOT NULL CHECK (platform IN ('ios', 'android')),
    source_platform text NOT NULL CHECK (source_platform IN ('apple_health', 'health_connect')),
    last_success_at timestamptz,
    last_attempt_at timestamptz,
    cursor_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    sync_status text NOT NULL DEFAULT 'idle'
        CHECK (sync_status IN ('idle', 'running', 'success', 'partial', 'error', 'locked')),
    last_error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, source_platform)
);

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

CREATE TABLE IF NOT EXISTS public.custom_symptoms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    label text NOT NULL,
    category text NOT NULL DEFAULT 'custom',
    icon_key text,
    is_hidden boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, profile_id, label)
);

CREATE TABLE IF NOT EXISTS public.symptom_favorites (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    symptom_type text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, profile_id, symptom_type)
);

CREATE TABLE IF NOT EXISTS public.health_insights (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    insight_key text NOT NULL,
    title text NOT NULL,
    observation text NOT NULL,
    recommendation text,
    confidence text NOT NULL CHECK (confidence IN ('preliminary', 'moderate', 'stronger', 'insufficient')),
    sample_size integer NOT NULL DEFAULT 0,
    window_days integer NOT NULL DEFAULT 30,
    supporting_factors jsonb NOT NULL DEFAULT '[]'::jsonb,
    limitations jsonb NOT NULL DEFAULT '[]'::jsonb,
    chart_payload jsonb,
    generated_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, insight_key, window_days)
);

CREATE INDEX IF NOT EXISTS idx_health_insights_profile_generated
    ON public.health_insights (profile_id, generated_at DESC);
