# Supabase Production Checklist

Date: 2026-05-26

- [x] Supabase project created (`hiair-prod`, `qhxesaemlhzwbunpqjoo`, `eu-central-1`)
- [x] env vars configured locally (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`, `DIRECT_DATABASE_URL` via Supabase server bootstrap; pooler `aws-1-eu-central-1:5432`)
- [ ] Google provider configured in Supabase Auth
- [ ] Apple provider configured in Supabase Auth
- [ ] redirect URLs configured (`hiair://auth/callback` and platform-specific callback URLs)
- [x] RLS enabled for primary user-owned tables (`profiles`, `symptom_logs`, `risk_scores`, `notification_events`, `user_settings`, `push_device_tokens`, `user_subscriptions`, `briefing_schedule`)
- [x] RLS policies tested (`select/insert/update/delete own rows`) on Supabase project `qhxesaemlhzwbunpqjoo` (risk_assessments/ai_recommendations/alert_events/personal_correlations + closed-table visibility check)
- [x] service_role never shipped to mobile builds (repo scan: no `service_role` / `SERVICE_ROLE` in `mobile/`)
- [x] privacy export tested for own-data-only behavior (backend API tests on Supabase-backed env)
- [x] privacy delete tested for own-account delete/cascade behavior (backend API tests on Supabase-backed env)
- [ ] iOS auth tested (email/password + OAuth + session restore + refresh + logout)
- [ ] Android auth tested (email/password + OAuth + session restore + refresh + logout)
