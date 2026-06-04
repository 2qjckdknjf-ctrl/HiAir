-- Repoint remaining legacy public.users FKs to auth.users (Supabase-first auth).

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'notification_delivery_attempts'
          AND constraint_name = 'notification_delivery_attempts_user_id_fkey'
    ) THEN
        ALTER TABLE public.notification_delivery_attempts
            DROP CONSTRAINT notification_delivery_attempts_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.notification_delivery_attempts
    ADD CONSTRAINT notification_delivery_attempts_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

DELETE FROM public.auth_refresh_tokens art
WHERE NOT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = art.user_id
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'auth_refresh_tokens'
          AND constraint_name = 'auth_refresh_tokens_user_id_fkey'
    ) THEN
        ALTER TABLE public.auth_refresh_tokens
            DROP CONSTRAINT auth_refresh_tokens_user_id_fkey;
    END IF;
END $$;

ALTER TABLE IF EXISTS public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
