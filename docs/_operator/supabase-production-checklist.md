# Supabase Production Checklist

Date: 2026-05-26

- [x] Supabase project created (`hiair-prod`, `qhxesaemlhzwbunpqjoo`, `eu-central-1`)
- [~] env vars configured (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) in local app configs; `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `DATABASE_URL`, `DIRECT_DATABASE_URL` still require secure production values
- [ ] Google provider configured in Supabase Auth
- [ ] Apple provider configured in Supabase Auth
- [ ] redirect URLs configured (`hiair://auth/callback` and platform-specific callback URLs)
- [x] RLS enabled for primary user-owned tables (`profiles`, `symptom_logs`, `risk_scores`, `notification_events`, `user_settings`, `push_device_tokens`, `user_subscriptions`, `briefing_schedule`)
- [x] RLS policies tested (`select/insert/update/delete own rows`) on Supabase project `qhxesaemlhzwbunpqjoo` (risk_assessments/ai_recommendations/alert_events/personal_correlations + closed-table visibility check)
- [ ] service_role never shipped to mobile builds
- [ ] privacy export tested for own-data-only behavior
- [ ] privacy delete tested for own-account delete/cascade behavior
- [ ] iOS auth tested (email/password + OAuth + session restore + refresh + logout)
- [ ] Android auth tested (email/password + OAuth + session restore + refresh + logout)
