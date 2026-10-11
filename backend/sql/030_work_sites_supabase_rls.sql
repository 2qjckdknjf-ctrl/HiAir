-- Ownership policies for Supabase; portable table DDL remains in 027.

DROP POLICY IF EXISTS work_sites_owner_select ON work_sites;

CREATE POLICY work_sites_owner_select ON work_sites
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_sites_owner_insert ON work_sites;

CREATE POLICY work_sites_owner_insert ON work_sites
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_sites_owner_delete ON work_sites;

CREATE POLICY work_sites_owner_delete ON work_sites
    FOR DELETE
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_site_wbgt_owner_select ON work_site_wbgt_readings;

CREATE POLICY work_site_wbgt_owner_select ON work_site_wbgt_readings
    FOR SELECT
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS work_site_wbgt_owner_insert ON work_site_wbgt_readings;

CREATE POLICY work_site_wbgt_owner_insert ON work_site_wbgt_readings
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);
