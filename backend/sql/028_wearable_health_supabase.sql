-- Supabase-only wearable/health FK + RLS (requires auth schema).

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth'
    ) THEN
        RAISE EXCEPTION 'auth schema required for 028_wearable_health_supabase.sql';
    END IF;
END $$;

ALTER TABLE IF EXISTS public.health_data_consents
    DROP CONSTRAINT IF EXISTS health_data_consents_user_id_fkey;
ALTER TABLE IF EXISTS public.health_data_consents
    ADD CONSTRAINT health_data_consents_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.wearable_daily_summaries
    DROP CONSTRAINT IF EXISTS wearable_daily_summaries_user_id_fkey;
ALTER TABLE IF EXISTS public.wearable_daily_summaries
    ADD CONSTRAINT wearable_daily_summaries_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.wearable_hourly_summaries
    DROP CONSTRAINT IF EXISTS wearable_hourly_summaries_user_id_fkey;
ALTER TABLE IF EXISTS public.wearable_hourly_summaries
    ADD CONSTRAINT wearable_hourly_summaries_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.wearable_metric_daily
    DROP CONSTRAINT IF EXISTS wearable_metric_daily_user_id_fkey;
ALTER TABLE IF EXISTS public.wearable_metric_daily
    ADD CONSTRAINT wearable_metric_daily_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.wearable_sleep_summaries
    DROP CONSTRAINT IF EXISTS wearable_sleep_summaries_user_id_fkey;
ALTER TABLE IF EXISTS public.wearable_sleep_summaries
    ADD CONSTRAINT wearable_sleep_summaries_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.wearable_sync_state
    DROP CONSTRAINT IF EXISTS wearable_sync_state_user_id_fkey;
ALTER TABLE IF EXISTS public.wearable_sync_state
    ADD CONSTRAINT wearable_sync_state_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.custom_symptoms
    DROP CONSTRAINT IF EXISTS custom_symptoms_user_id_fkey;
ALTER TABLE IF EXISTS public.custom_symptoms
    ADD CONSTRAINT custom_symptoms_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.symptom_favorites
    DROP CONSTRAINT IF EXISTS symptom_favorites_user_id_fkey;
ALTER TABLE IF EXISTS public.symptom_favorites
    ADD CONSTRAINT symptom_favorites_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.health_insights
    DROP CONSTRAINT IF EXISTS health_insights_user_id_fkey;
ALTER TABLE IF EXISTS public.health_insights
    ADD CONSTRAINT health_insights_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.health_data_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_hourly_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_metric_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_sleep_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wearable_sync_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_symptoms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.symptom_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_insights ENABLE ROW LEVEL SECURITY;

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
DROP POLICY IF EXISTS wearable_daily_summaries_delete_own ON public.wearable_daily_summaries
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

DROP POLICY IF EXISTS wearable_metric_daily_select_own ON public.wearable_metric_daily;
CREATE POLICY wearable_metric_daily_select_own ON public.wearable_metric_daily
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_metric_daily_insert_own ON public.wearable_metric_daily;
CREATE POLICY wearable_metric_daily_insert_own ON public.wearable_metric_daily
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_metric_daily_update_own ON public.wearable_metric_daily;
CREATE POLICY wearable_metric_daily_update_own ON public.wearable_metric_daily
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_metric_daily_delete_own ON public.wearable_metric_daily;
CREATE POLICY wearable_metric_daily_delete_own ON public.wearable_metric_daily
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_sleep_summaries_select_own ON public.wearable_sleep_summaries;
CREATE POLICY wearable_sleep_summaries_select_own ON public.wearable_sleep_summaries
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sleep_summaries_insert_own ON public.wearable_sleep_summaries;
CREATE POLICY wearable_sleep_summaries_insert_own ON public.wearable_sleep_summaries
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sleep_summaries_update_own ON public.wearable_sleep_summaries;
CREATE POLICY wearable_sleep_summaries_update_own ON public.wearable_sleep_summaries
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sleep_summaries_delete_own ON public.wearable_sleep_summaries;
CREATE POLICY wearable_sleep_summaries_delete_own ON public.wearable_sleep_summaries
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS wearable_sync_state_select_own ON public.wearable_sync_state;
CREATE POLICY wearable_sync_state_select_own ON public.wearable_sync_state
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sync_state_insert_own ON public.wearable_sync_state;
CREATE POLICY wearable_sync_state_insert_own ON public.wearable_sync_state
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sync_state_update_own ON public.wearable_sync_state;
CREATE POLICY wearable_sync_state_update_own ON public.wearable_sync_state
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS wearable_sync_state_delete_own ON public.wearable_sync_state;
CREATE POLICY wearable_sync_state_delete_own ON public.wearable_sync_state
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS custom_symptoms_select_own ON public.custom_symptoms;
CREATE POLICY custom_symptoms_select_own ON public.custom_symptoms
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS custom_symptoms_insert_own ON public.custom_symptoms;
CREATE POLICY custom_symptoms_insert_own ON public.custom_symptoms
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS custom_symptoms_update_own ON public.custom_symptoms;
CREATE POLICY custom_symptoms_update_own ON public.custom_symptoms
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS custom_symptoms_delete_own ON public.custom_symptoms;
CREATE POLICY custom_symptoms_delete_own ON public.custom_symptoms
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS symptom_favorites_select_own ON public.symptom_favorites;
CREATE POLICY symptom_favorites_select_own ON public.symptom_favorites
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS symptom_favorites_insert_own ON public.symptom_favorites;
CREATE POLICY symptom_favorites_insert_own ON public.symptom_favorites
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS symptom_favorites_update_own ON public.symptom_favorites;
CREATE POLICY symptom_favorites_update_own ON public.symptom_favorites
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS symptom_favorites_delete_own ON public.symptom_favorites;
CREATE POLICY symptom_favorites_delete_own ON public.symptom_favorites
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS health_insights_select_own ON public.health_insights;
CREATE POLICY health_insights_select_own ON public.health_insights
    FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS health_insights_insert_own ON public.health_insights;
CREATE POLICY health_insights_insert_own ON public.health_insights
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS health_insights_update_own ON public.health_insights;
CREATE POLICY health_insights_update_own ON public.health_insights
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS health_insights_delete_own ON public.health_insights;
CREATE POLICY health_insights_delete_own ON public.health_insights
    FOR DELETE USING ((SELECT auth.uid()) = user_id);
