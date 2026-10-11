-- Deletion operations are server-owned; clients use the authenticated privacy API.
ALTER TABLE account_deletion_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_deletion_stage_events ENABLE ROW LEVEL SECURITY;
DO $$
DECLARE client_role TEXT;
BEGIN
    FOREACH client_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = client_role) THEN
            EXECUTE format('REVOKE ALL ON account_deletion_operations, account_deletion_stage_events FROM %I', client_role);
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON account_deletion_operations, account_deletion_stage_events TO service_role;
    END IF;
END $$;
REVOKE ALL ON account_deletion_operations, account_deletion_stage_events FROM PUBLIC;
