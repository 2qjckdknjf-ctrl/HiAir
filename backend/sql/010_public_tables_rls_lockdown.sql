-- Lock down remaining public tables with RLS.
-- User-owned analytics tables get own-row policies via profiles ownership.
-- Operational/internal tables are protected by enabling RLS without anon/authenticated policies.

-- Enable RLS on all remaining public tables reported by advisor.
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.environment_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notification_delivery_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscription_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notification_secret_rotation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.alert_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ai_prompt_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ai_explanation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.personal_correlations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.auth_refresh_tokens ENABLE ROW LEVEL SECURITY;

-- risk_assessments (profile-owned)
DROP POLICY IF EXISTS risk_assessments_select_own ON public.risk_assessments;
DROP POLICY IF EXISTS risk_assessments_insert_own ON public.risk_assessments;
DROP POLICY IF EXISTS risk_assessments_update_own ON public.risk_assessments;
DROP POLICY IF EXISTS risk_assessments_delete_own ON public.risk_assessments;

CREATE POLICY risk_assessments_select_own ON public.risk_assessments
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = risk_assessments.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY risk_assessments_insert_own ON public.risk_assessments
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = risk_assessments.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY risk_assessments_update_own ON public.risk_assessments
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = risk_assessments.user_profile_id
              AND p.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = risk_assessments.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY risk_assessments_delete_own ON public.risk_assessments
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = risk_assessments.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

-- ai_recommendations (owned through risk_assessments -> profiles)
DROP POLICY IF EXISTS ai_recommendations_select_own ON public.ai_recommendations;
DROP POLICY IF EXISTS ai_recommendations_insert_own ON public.ai_recommendations;
DROP POLICY IF EXISTS ai_recommendations_update_own ON public.ai_recommendations;
DROP POLICY IF EXISTS ai_recommendations_delete_own ON public.ai_recommendations;

CREATE POLICY ai_recommendations_select_own ON public.ai_recommendations
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.risk_assessments ra
            JOIN public.profiles p ON p.id = ra.user_profile_id
            WHERE ra.id = ai_recommendations.risk_assessment_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY ai_recommendations_insert_own ON public.ai_recommendations
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.risk_assessments ra
            JOIN public.profiles p ON p.id = ra.user_profile_id
            WHERE ra.id = ai_recommendations.risk_assessment_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY ai_recommendations_update_own ON public.ai_recommendations
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.risk_assessments ra
            JOIN public.profiles p ON p.id = ra.user_profile_id
            WHERE ra.id = ai_recommendations.risk_assessment_id
              AND p.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.risk_assessments ra
            JOIN public.profiles p ON p.id = ra.user_profile_id
            WHERE ra.id = ai_recommendations.risk_assessment_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY ai_recommendations_delete_own ON public.ai_recommendations
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.risk_assessments ra
            JOIN public.profiles p ON p.id = ra.user_profile_id
            WHERE ra.id = ai_recommendations.risk_assessment_id
              AND p.user_id = auth.uid()
        )
    );

-- alert_events (profile-owned)
DROP POLICY IF EXISTS alert_events_select_own ON public.alert_events;
DROP POLICY IF EXISTS alert_events_insert_own ON public.alert_events;
DROP POLICY IF EXISTS alert_events_update_own ON public.alert_events;
DROP POLICY IF EXISTS alert_events_delete_own ON public.alert_events;

CREATE POLICY alert_events_select_own ON public.alert_events
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = alert_events.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY alert_events_insert_own ON public.alert_events
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = alert_events.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY alert_events_update_own ON public.alert_events
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = alert_events.user_profile_id
              AND p.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = alert_events.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY alert_events_delete_own ON public.alert_events
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = alert_events.user_profile_id
              AND p.user_id = auth.uid()
        )
    );

-- personal_correlations (profile-owned)
DROP POLICY IF EXISTS personal_correlations_select_own ON public.personal_correlations;
DROP POLICY IF EXISTS personal_correlations_insert_own ON public.personal_correlations;
DROP POLICY IF EXISTS personal_correlations_update_own ON public.personal_correlations;
DROP POLICY IF EXISTS personal_correlations_delete_own ON public.personal_correlations;

CREATE POLICY personal_correlations_select_own ON public.personal_correlations
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = personal_correlations.profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY personal_correlations_insert_own ON public.personal_correlations
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = personal_correlations.profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY personal_correlations_update_own ON public.personal_correlations
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = personal_correlations.profile_id
              AND p.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = personal_correlations.profile_id
              AND p.user_id = auth.uid()
        )
    );

CREATE POLICY personal_correlations_delete_own ON public.personal_correlations
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = personal_correlations.profile_id
              AND p.user_id = auth.uid()
        )
    );
