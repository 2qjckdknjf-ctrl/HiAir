-- Supabase RLS for HiAir 1.5-1.6 tables (requires auth schema).

ALTER TABLE saved_places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS saved_places_owner_select ON saved_places;
CREATE POLICY saved_places_owner_select ON saved_places
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS saved_places_owner_insert ON saved_places;
CREATE POLICY saved_places_owner_insert ON saved_places
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS saved_places_owner_delete ON saved_places;
CREATE POLICY saved_places_owner_delete ON saved_places
    FOR DELETE
    USING (auth.uid()::text = user_id);

ALTER TABLE protected_day_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS protected_day_events_owner_select ON protected_day_events;
CREATE POLICY protected_day_events_owner_select ON protected_day_events
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS protected_day_events_owner_insert ON protected_day_events;
CREATE POLICY protected_day_events_owner_insert ON protected_day_events
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

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
