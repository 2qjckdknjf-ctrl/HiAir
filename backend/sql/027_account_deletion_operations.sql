-- Durable account deletion operations (no PII; hashed user id only).
-- Each stage is tracked independently for idempotent resume.

CREATE TABLE IF NOT EXISTS account_deletion_operations (
    operation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_hash TEXT NOT NULL,
    auth_provider TEXT NOT NULL DEFAULT 'unknown',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'completed', 'failed')),
    apple_revoke_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (apple_revoke_status IN ('pending', 'completed', 'not_applicable', 'failed')),
    public_data_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (public_data_status IN ('pending', 'completed', 'not_applicable', 'failed')),
    supabase_auth_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (supabase_auth_status IN ('pending', 'completed', 'not_applicable', 'failed')),
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_deletion_operations_active_user
    ON account_deletion_operations (user_id_hash)
    WHERE status IN ('pending', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_account_deletion_operations_status_updated
    ON account_deletion_operations (status, updated_at DESC);

CREATE TABLE IF NOT EXISTS account_deletion_stage_events (
    id BIGSERIAL PRIMARY KEY,
    operation_id UUID NOT NULL REFERENCES account_deletion_operations(operation_id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    status TEXT NOT NULL,
    detail TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_stage_events_operation
    ON account_deletion_stage_events (operation_id, recorded_at DESC);

DROP TABLE IF EXISTS account_deletion_audit;
