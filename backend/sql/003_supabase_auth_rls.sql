-- Supabase-first auth migration + RLS baseline.
-- NOTE: Keep legacy table names to avoid API breakage; enforce ownership via auth.users.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------
-- profiles
-- ----------------------------
ALTER TABLE IF EXISTS public.profiles
    ALTER COLUMN id SET DEFAULT gen_random_uuid(),
    ALTER COLUMN user_id SET NOT NULL,
    ALTER COLUMN persona_type SET NOT NULL,
    ALTER COLUMN sensitivity_level DROP NOT NULL,
    ALTER COLUMN home_lat DROP NOT NULL,
    ALTER COLUMN home_lon DROP NOT NULL,
    ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE IF EXISTS public.profiles
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'profiles'
          AND constraint_name = 'profiles_user_id_fkey'
    ) THEN
        ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.profiles
    ADD CONSTRAINT profiles_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- symptom_logs
-- ----------------------------
ALTER TABLE IF EXISTS public.symptom_logs
    ADD COLUMN IF NOT EXISTS user_id uuid,
    ALTER COLUMN id SET DEFAULT gen_random_uuid(),
    ALTER COLUMN created_at SET DEFAULT now();

UPDATE public.symptom_logs s
SET user_id = p.user_id
FROM public.profiles p
WHERE s.profile_id = p.id
  AND s.user_id IS NULL;

ALTER TABLE IF EXISTS public.symptom_logs
    ALTER COLUMN user_id SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'symptom_logs'
          AND constraint_name = 'symptom_logs_user_id_fkey'
    ) THEN
        ALTER TABLE public.symptom_logs DROP CONSTRAINT symptom_logs_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.symptom_logs
    ADD CONSTRAINT symptom_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- risk_scores
-- ----------------------------
ALTER TABLE IF EXISTS public.risk_scores
    ADD COLUMN IF NOT EXISTS user_id uuid,
    ALTER COLUMN id SET DEFAULT gen_random_uuid(),
    ALTER COLUMN score_value TYPE numeric USING score_value::numeric,
    ALTER COLUMN score_value SET NOT NULL,
    ALTER COLUMN risk_level SET NOT NULL,
    ALTER COLUMN recommendations_json SET DEFAULT '[]'::jsonb,
    ALTER COLUMN created_at SET DEFAULT now();

UPDATE public.risk_scores r
SET user_id = p.user_id
FROM public.profiles p
WHERE r.profile_id = p.id
  AND r.user_id IS NULL;

ALTER TABLE IF EXISTS public.risk_scores
    ALTER COLUMN user_id SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'risk_scores'
          AND constraint_name = 'risk_scores_user_id_fkey'
    ) THEN
        ALTER TABLE public.risk_scores DROP CONSTRAINT risk_scores_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.risk_scores
    ADD CONSTRAINT risk_scores_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- notification_events (profile-owned + user ownership)
-- ----------------------------
ALTER TABLE IF EXISTS public.notification_events
    ADD COLUMN IF NOT EXISTS user_id uuid;

UPDATE public.notification_events ne
SET user_id = p.user_id
FROM public.profiles p
WHERE ne.profile_id = p.id
  AND ne.user_id IS NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'notification_events'
          AND constraint_name = 'notification_events_user_id_fkey'
    ) THEN
        ALTER TABLE public.notification_events DROP CONSTRAINT notification_events_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.notification_events
    ADD CONSTRAINT notification_events_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- user_settings
-- ----------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'user_settings'
          AND constraint_name = 'user_settings_user_id_fkey'
    ) THEN
        ALTER TABLE public.user_settings DROP CONSTRAINT user_settings_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.user_settings
    ADD CONSTRAINT user_settings_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- push_device_tokens
-- ----------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'push_device_tokens'
          AND constraint_name = 'push_device_tokens_user_id_fkey'
    ) THEN
        ALTER TABLE public.push_device_tokens DROP CONSTRAINT push_device_tokens_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.push_device_tokens
    ADD CONSTRAINT push_device_tokens_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- user_subscriptions
-- ----------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'user_subscriptions'
          AND constraint_name = 'user_subscriptions_user_id_fkey'
    ) THEN
        ALTER TABLE public.user_subscriptions DROP CONSTRAINT user_subscriptions_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- briefing_schedule (privacy-owned user table)
-- ----------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'briefing_schedule'
          AND constraint_name = 'briefing_schedule_user_id_fkey'
    ) THEN
        ALTER TABLE public.briefing_schedule DROP CONSTRAINT briefing_schedule_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.briefing_schedule
    ADD CONSTRAINT briefing_schedule_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ----------------------------
-- indexes
-- ----------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_user_id
    ON public.profiles (user_id);
CREATE INDEX IF NOT EXISTS idx_symptom_logs_user_created_at
    ON public.symptom_logs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_symptom_logs_profile_created_at
    ON public.symptom_logs (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_scores_user_created_at
    ON public.risk_scores (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_scores_profile_created_at
    ON public.risk_scores (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_events_user_created_at
    ON public.notification_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_id
    ON public.push_device_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id
    ON public.user_subscriptions (user_id);

-- ----------------------------
-- RLS
-- ----------------------------
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.symptom_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.risk_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.push_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.briefing_schedule ENABLE ROW LEVEL SECURITY;

-- Clean up previous policies if they exist.
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
DROP POLICY IF EXISTS profiles_delete_own ON public.profiles;

DROP POLICY IF EXISTS symptom_logs_select_own ON public.symptom_logs;
DROP POLICY IF EXISTS symptom_logs_insert_own ON public.symptom_logs;
DROP POLICY IF EXISTS symptom_logs_update_own ON public.symptom_logs;
DROP POLICY IF EXISTS symptom_logs_delete_own ON public.symptom_logs;

DROP POLICY IF EXISTS risk_scores_select_own ON public.risk_scores;
DROP POLICY IF EXISTS risk_scores_insert_own ON public.risk_scores;
DROP POLICY IF EXISTS risk_scores_update_own ON public.risk_scores;
DROP POLICY IF EXISTS risk_scores_delete_own ON public.risk_scores;

DROP POLICY IF EXISTS notification_events_select_own ON public.notification_events;
DROP POLICY IF EXISTS notification_events_insert_own ON public.notification_events;
DROP POLICY IF EXISTS notification_events_update_own ON public.notification_events;
DROP POLICY IF EXISTS notification_events_delete_own ON public.notification_events;

DROP POLICY IF EXISTS user_settings_select_own ON public.user_settings;
DROP POLICY IF EXISTS user_settings_insert_own ON public.user_settings;
DROP POLICY IF EXISTS user_settings_update_own ON public.user_settings;
DROP POLICY IF EXISTS user_settings_delete_own ON public.user_settings;

DROP POLICY IF EXISTS push_device_tokens_select_own ON public.push_device_tokens;
DROP POLICY IF EXISTS push_device_tokens_insert_own ON public.push_device_tokens;
DROP POLICY IF EXISTS push_device_tokens_update_own ON public.push_device_tokens;
DROP POLICY IF EXISTS push_device_tokens_delete_own ON public.push_device_tokens;

DROP POLICY IF EXISTS user_subscriptions_select_own ON public.user_subscriptions;
DROP POLICY IF EXISTS user_subscriptions_insert_own ON public.user_subscriptions;
DROP POLICY IF EXISTS user_subscriptions_update_own ON public.user_subscriptions;
DROP POLICY IF EXISTS user_subscriptions_delete_own ON public.user_subscriptions;

DROP POLICY IF EXISTS briefing_schedule_select_own ON public.briefing_schedule;
DROP POLICY IF EXISTS briefing_schedule_insert_own ON public.briefing_schedule;
DROP POLICY IF EXISTS briefing_schedule_update_own ON public.briefing_schedule;
DROP POLICY IF EXISTS briefing_schedule_delete_own ON public.briefing_schedule;

-- profiles
CREATE POLICY profiles_select_own ON public.profiles
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY profiles_insert_own ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY profiles_delete_own ON public.profiles
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- symptom_logs
CREATE POLICY symptom_logs_select_own ON public.symptom_logs
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY symptom_logs_insert_own ON public.symptom_logs
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY symptom_logs_update_own ON public.symptom_logs
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY symptom_logs_delete_own ON public.symptom_logs
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- risk_scores
CREATE POLICY risk_scores_select_own ON public.risk_scores
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY risk_scores_insert_own ON public.risk_scores
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY risk_scores_update_own ON public.risk_scores
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY risk_scores_delete_own ON public.risk_scores
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- notification_events
CREATE POLICY notification_events_select_own ON public.notification_events
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_events_insert_own ON public.notification_events
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_events_update_own ON public.notification_events
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY notification_events_delete_own ON public.notification_events
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- user_settings
CREATE POLICY user_settings_select_own ON public.user_settings
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY user_settings_insert_own ON public.user_settings
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_settings_update_own ON public.user_settings
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_settings_delete_own ON public.user_settings
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- push_device_tokens
CREATE POLICY push_device_tokens_select_own ON public.push_device_tokens
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY push_device_tokens_insert_own ON public.push_device_tokens
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY push_device_tokens_update_own ON public.push_device_tokens
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY push_device_tokens_delete_own ON public.push_device_tokens
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- user_subscriptions
CREATE POLICY user_subscriptions_select_own ON public.user_subscriptions
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY user_subscriptions_insert_own ON public.user_subscriptions
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_subscriptions_update_own ON public.user_subscriptions
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY user_subscriptions_delete_own ON public.user_subscriptions
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- briefing_schedule
CREATE POLICY briefing_schedule_select_own ON public.briefing_schedule
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);
CREATE POLICY briefing_schedule_insert_own ON public.briefing_schedule
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY briefing_schedule_update_own ON public.briefing_schedule
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY briefing_schedule_delete_own ON public.briefing_schedule
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);
