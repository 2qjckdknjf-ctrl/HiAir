-- RLS lockdown for tables flagged by Supabase security advisor (2026-06-17).
-- Backend service connections bypass RLS; these policies protect PostgREST exposure.

ALTER TABLE IF EXISTS public.waitlist_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.schema_migrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.provider_transactions ENABLE ROW LEVEL SECURITY;

-- Public read-only subscription catalog.
DROP POLICY IF EXISTS subscription_plans_select_all ON public.subscription_plans;
CREATE POLICY subscription_plans_select_all ON public.subscription_plans
    FOR SELECT TO anon, authenticated
    USING (true);

-- User entitlements: own row only.
DROP POLICY IF EXISTS user_entitlements_select_own ON public.user_entitlements;
CREATE POLICY user_entitlements_select_own ON public.user_entitlements
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Provider transaction audit: own rows only.
DROP POLICY IF EXISTS provider_transactions_select_own ON public.provider_transactions;
CREATE POLICY provider_transactions_select_own ON public.provider_transactions
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- waitlist_signups and schema_migrations: RLS enabled with no anon/authenticated policies.
