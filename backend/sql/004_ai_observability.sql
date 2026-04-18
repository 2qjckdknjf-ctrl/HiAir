CREATE TABLE IF NOT EXISTS ai_prompt_versions (
    id UUID PRIMARY KEY,
    prompt_key TEXT NOT NULL,
    version TEXT NOT NULL,
    prompt_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (prompt_key, version)
);

CREATE TABLE IF NOT EXISTS ai_explanation_events (
    id UUID PRIMARY KEY,
    user_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    risk_assessment_id UUID REFERENCES risk_assessments(id) ON DELETE SET NULL,
    prompt_key TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    model_name TEXT,
    used_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    guardrail_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason TEXT,
    generated_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_prompt_versions_key_active
    ON ai_prompt_versions(prompt_key, is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_explanation_events_profile_time
    ON ai_explanation_events(user_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_explanation_events_fallback_time
    ON ai_explanation_events(used_fallback, guardrail_blocked, created_at DESC);
