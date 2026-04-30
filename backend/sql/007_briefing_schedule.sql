CREATE TABLE IF NOT EXISTS briefing_schedule (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    local_time TIME NOT NULL DEFAULT '07:30',
    timezone TEXT NOT NULL DEFAULT 'UTC',
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    last_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_briefing_schedule_enabled
    ON briefing_schedule(enabled, local_time);
