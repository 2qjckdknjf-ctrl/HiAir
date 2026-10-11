import sys
import time
from pathlib import Path

from psycopg import connect
from psycopg.errors import DeadlockDetected

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.settings import settings

INIT_DB_LOCK_KEY = 8_314_159_265
MAX_DEADLOCK_RETRIES = 4

SUPABASE_AUTH_MIGRATIONS = {
    "003_supabase_auth_rls.sql",
    "010_public_tables_rls_lockdown.sql",
    "011_supabase_auth_user_fk_fixup.sql",
    "013_supabase_entitlements_auth_user_fk.sql",
    "017_rls_subscription_waitlist_lockdown.sql",
    "018_health_intelligence.sql",
    "021_saved_places.sql",
    "022_protected_day_events.sql",
    "023_family_member_links.sql",
    "027_work_sites_instrument_wbgt.sql",
