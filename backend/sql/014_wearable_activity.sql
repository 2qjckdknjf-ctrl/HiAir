-- Wearable & Activity Intelligence v1 (portable DDL for CI/local PostgreSQL).
-- Supabase FK + RLS: 028_wearable_health_supabase.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.health_data_consents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    platform text NOT NULL CHECK (platform IN ('ios', 'android')),
    source text NOT NULL CHECK (source IN ('apple_health', 'health_connect')),
    steps_enabled boolean NOT NULL DEFAULT false,
    heart_rate_enabled boolean NOT NULL DEFAULT false,
    resting_heart_rate_enabled boolean NOT NULL DEFAULT false,
    hrv_enabled boolean NOT NULL DEFAULT false,
    sleep_enabled boolean NOT NULL DEFAULT false,
    consent_version text NOT NULL,
    accepted_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_health_data_consents_user_id
    ON public.health_data_consents (user_id);
CREATE INDEX IF NOT EXISTS idx_health_data_consents_user_source
    ON public.health_data_consents (user_id, source);
CREATE INDEX IF NOT EXISTS idx_health_data_consents_accepted_revoked
    ON public.health_data_consents (accepted_at, revoked_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_health_data_consents_user_source_unique
    ON public.health_data_consents (user_id, source);

CREATE TABLE IF NOT EXISTS public.wearable_daily_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    date date NOT NULL,
    steps_total integer,
    steps_goal integer,
    heart_rate_avg numeric,
    heart_rate_min numeric,
    heart_rate_max numeric,
    resting_heart_rate_avg numeric,
    resting_heart_rate_delta numeric,
    hrv_avg numeric,
    sleep_minutes integer,
    source text NOT NULL CHECK (source IN ('apple_health', 'health_connect')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, date, source)
);

CREATE INDEX IF NOT EXISTS idx_wearable_daily_user_date
    ON public.wearable_daily_summaries (user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_wearable_daily_user_source
    ON public.wearable_daily_summaries (user_id, source);

CREATE TABLE IF NOT EXISTS public.wearable_hourly_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    hour_start timestamptz NOT NULL,
    steps_total integer,
    heart_rate_avg numeric,
    heart_rate_max numeric,
    source text NOT NULL CHECK (source IN ('apple_health', 'health_connect')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, hour_start, source)
);

CREATE INDEX IF NOT EXISTS idx_wearable_hourly_user_hour
    ON public.wearable_hourly_summaries (user_id, hour_start DESC);
CREATE INDEX IF NOT EXISTS idx_wearable_hourly_user_source
    ON public.wearable_hourly_summaries (user_id, source);
