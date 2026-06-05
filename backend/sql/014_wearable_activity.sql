-- Wearable & Activity Intelligence v1
-- Aggregated health summaries with explicit user consent.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------
-- health_data_consents
-- ----------------------------
CREATE TABLE IF NOT EXISTS public.health_data_consents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- One active consent row per user+source (latest wins via upsert in app layer).
CREATE UNIQUE INDEX IF NOT EXISTS idx_health_data_consents_user_source_unique
    ON public.health_data_consents (user_id, source);

-- ----------------------------
-- wearable_daily_summaries
-- ----------------------------
CREATE TABLE IF NOT EXISTS public.wearable_daily_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- ----------------------------
-- wearable_hourly_summaries
-- ----------------------------
CREATE TABLE IF NOT EXISTS public.wearable_hourly_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- ----------------------------
-- RLS: direct user ownership (003 pattern)
-- ----------------------------
ALTER TABLE public.health_data_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_hourly_summaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS health_data_consents_select_own ON public.health_data_consents;
CREATE POLICY health_data_consents_select_own ON public.health_data_consents
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS health_data_consents_insert_own ON public.health_data_consents;
CREATE POLICY health_data_consents_insert_own ON public.health_data_consents
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS health_data_consents_update_own ON public.health_data_consents;
CREATE POLICY health_data_consents_update_own ON public.health_data_consents
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS health_data_consents_delete_own ON public.health_data_consents;
CREATE POLICY health_data_consents_delete_own ON public.health_data_consents
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_daily_summaries_select_own ON public.wearable_daily_summaries;
CREATE POLICY wearable_daily_summaries_select_own ON public.wearable_daily_summaries
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_daily_summaries_insert_own ON public.wearable_daily_summaries;
CREATE POLICY wearable_daily_summaries_insert_own ON public.wearable_daily_summaries
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_daily_summaries_update_own ON public.wearable_daily_summaries;
CREATE POLICY wearable_daily_summaries_update_own ON public.wearable_daily_summaries
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_daily_summaries_delete_own ON public.wearable_daily_summaries;
CREATE POLICY wearable_daily_summaries_delete_own ON public.wearable_daily_summaries
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_hourly_summaries_select_own ON public.wearable_hourly_summaries;
CREATE POLICY wearable_hourly_summaries_select_own ON public.wearable_hourly_summaries
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_hourly_summaries_insert_own ON public.wearable_hourly_summaries;
CREATE POLICY wearable_hourly_summaries_insert_own ON public.wearable_hourly_summaries
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_hourly_summaries_update_own ON public.wearable_hourly_summaries;
CREATE POLICY wearable_hourly_summaries_update_own ON public.wearable_hourly_summaries
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_hourly_summaries_delete_own ON public.wearable_hourly_summaries;
CREATE POLICY wearable_hourly_summaries_delete_own ON public.wearable_hourly_summaries
    FOR DELETE USING ((SELECT auth.uid()) = user_id);
