-- Minimal, non-PII audit trail for account deletion retries/recovery.
-- Stores only a hashed user id and stage outcomes (no email, tokens, or profile data).

CREATE TABLE IF NOT EXISTS account_deletion_audit (
    user_id_hash TEXT PRIMARY KEY,
    last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stage_status JSONB NOT NULL DEFAULT '{}'::jsonb,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    attempt_count INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_audit_incomplete
    ON account_deletion_audit (completed, last_attempt_at DESC)
    WHERE completed = FALSE;
