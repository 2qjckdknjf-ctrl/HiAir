"""Real DB lifecycle: integrated place/work data is owner-bound and removable."""
from uuid import uuid4

from app.services.db import get_connection
from app.services.privacy_repository import delete_user_data, export_user_data
from scripts.init_db import main as init_db


def test_feature_export_and_delete_preserve_other_accounts():
    init_db()
    owner, other = str(uuid4()), str(uuid4())
    places = []
    sites = []
    try:
        with get_connection() as conn:
            for user in (owner, other):
                conn.execute("INSERT INTO users(id,email,password_hash) VALUES (%s,%s,'test-only')",
                             (user, f"{user}@example.test"))
                place = str(uuid4())
                conn.execute("INSERT INTO saved_places(id,user_id,name,place_type,lat,lon) VALUES (%s,%s,'Home','home',41,2)", (place, user))
                places.append(place)
                site = str(uuid4())
                conn.execute("INSERT INTO work_sites(id,user_id,name,lat,lon) VALUES (%s,%s,'Site',41,2)", (site, user))
                sites.append(site)
                conn.execute("INSERT INTO work_site_wbgt_readings(user_id,site_id,wbgt_c,measured_at) VALUES (%s,%s,24,NOW())", (user, site))
        exported = export_user_data(owner)
        assert [row['id'] for row in exported['saved_places']] == [places[0]]
        assert [row['id'] for row in exported['work_sites']] == [sites[0]]
        assert len(exported['work_site_wbgt_readings']) == 1
        assert all(row['user_id'] == owner for row in exported['work_site_wbgt_readings'])
        assert delete_user_data(owner)
        with get_connection() as conn:
            for table in ('saved_places', 'work_sites', 'work_site_wbgt_readings'):
                assert conn.execute(f"SELECT count(*) AS count FROM {table} WHERE user_id=%s", (owner,)).fetchone()['count'] == 0
                assert conn.execute(f"SELECT count(*) AS count FROM {table} WHERE user_id=%s", (other,)).fetchone()['count'] == 1
    finally:
        delete_user_data(owner)
        delete_user_data(other)
