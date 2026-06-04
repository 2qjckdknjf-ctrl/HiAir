-- Supabase-first: entitlement tables must reference auth.users (not legacy public.users).

ALTER TABLE IF EXISTS public.user_entitlements
    DROP CONSTRAINT IF EXISTS user_entitlements_user_id_fkey;

ALTER TABLE IF EXISTS public.user_entitlements
    ADD CONSTRAINT user_entitlements_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.provider_transactions
    DROP CONSTRAINT IF EXISTS provider_transactions_user_id_fkey;

ALTER TABLE IF EXISTS public.provider_transactions
    ADD CONSTRAINT provider_transactions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
