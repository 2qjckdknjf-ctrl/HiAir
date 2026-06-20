CREATE TABLE IF NOT EXISTS product_analytics_events (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_id TEXT NOT NULL,
    event_name TEXT NOT NULL,
    properties JSONB NOT NULL DEFAULT '{}'::JSONB,
    platform TEXT NOT NULL DEFAULT 'unknown',
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_analytics_event_name_time
    ON product_analytics_events(event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_analytics_session_id
    ON product_analytics_events(session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_analytics_user_id
    ON product_analytics_events(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS product_feedback (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    platform TEXT NOT NULL DEFAULT 'unknown',
    liked TEXT NOT NULL DEFAULT '',
    confusing TEXT NOT NULL DEFAULT '',
    broken TEXT NOT NULL DEFAULT '',
    contact_email TEXT,
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_feedback_created_at
    ON product_feedback(created_at DESC);

CREATE TABLE IF NOT EXISTS product_crash_reports (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_id TEXT,
    platform TEXT NOT NULL DEFAULT 'unknown',
    message TEXT NOT NULL,
    stack_trace TEXT,
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_crash_reports_created_at
    ON product_crash_reports(created_at DESC);
