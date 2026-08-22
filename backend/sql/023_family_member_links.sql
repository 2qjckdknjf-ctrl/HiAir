-- HiAir 1.5 family member profile links (caregiver monitoring)

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

ALTER TABLE family_member_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS family_member_links_owner_select ON family_member_links;
CREATE POLICY family_member_links_owner_select ON family_member_links
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS family_member_links_owner_insert ON family_member_links;
CREATE POLICY family_member_links_owner_insert ON family_member_links
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS family_member_links_owner_delete ON family_member_links;
CREATE POLICY family_member_links_owner_delete ON family_member_links
    FOR DELETE
    USING (auth.uid()::text = user_id);
