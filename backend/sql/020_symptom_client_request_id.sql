-- Idempotent symptom creates for offline retry / double-submit protection.
-- CI/local DBs may skip 003 (auth) so symptom_logs.user_id might be absent;
-- add a nullable uuid column without auth.users FK for index compatibility.

ALTER TABLE IF EXISTS public.symptom_logs
    ADD COLUMN IF NOT EXISTS client_request_id text;

ALTER TABLE IF EXISTS public.symptom_logs
    ADD COLUMN IF NOT EXISTS user_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS idx_symptom_logs_user_client_request
    ON public.symptom_logs (user_id, client_request_id)
    WHERE client_request_id IS NOT NULL
      AND deleted_at IS NULL;
