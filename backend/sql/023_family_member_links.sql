-- HiAir 1.5 family member profile links (caregiver monitoring)
-- Table DDL is CI-compatible; RLS policies live in 025_supabase_table_rls.sql.

CREATE TABLE IF NOT EXISTS family_member_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    member_profile_id TEXT NOT NULL,
    relation TEXT NOT NULL,
    label TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT family_member_links_relation_check
        CHECK (relation IN ('child', 'parent', 'elderly', 'partner', 'other')),
    CONSTRAINT family_member_links_unique_member
        UNIQUE (user_id, member_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_family_member_links_user_created
    ON family_member_links (user_id, created_at DESC);
