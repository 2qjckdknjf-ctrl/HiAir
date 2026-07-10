# HiAir Subscription Product Model

## Plans

### Free

- 1 primary profile (`max_profiles = 1`)
- Current risk score (`/api/air/current-risk`)
- Basic recommendations (`/api/air/recommendations`)
- Basic notifications (push settings, standard alerts)
- Basic forecast (dashboard snapshot; not full day-plan)

### Premium

- Family profiles (`max_profiles = 6`)
- Extended forecast (`/api/air/day-plan`, `/api/planner/daily`)
- Custom alerts / briefing schedule (`/api/briefings/schedule` PUT)
- Exportable reports (`/api/privacy/export`)
- Advanced insights (`/api/insights/correlations`)
- Daily AI recommendations (`/api/recommendations/daily`)
- Future wearable insights (reserved flag)
- Priority notifications (reserved flag)

## Store product IDs

| Billing | iOS | Android |
|---------|-----|---------|
| Monthly | `com.hiair.premium.monthly` | `hiair_premium_monthly` |
| Yearly | `com.hiair.premium.yearly` | `hiair_premium_yearly` |

Internal plan keys: `premium_monthly`, `premium_yearly` (stub/dev may still accept legacy `basic_*`).

## Feature matrix

| Feature | Free limit | Premium limit | Backend guard | Mobile UI |
|---------|------------|---------------|---------------|-----------|
| Profiles | 1 | 6 | `entitlement_service.assert_profile_limit` — `profiles.py` | Paywall on 2nd profile; Settings |
| Current risk | Yes | Yes | None (free) | Dashboard |
| Basic recommendations | Yes | Yes | None | Dashboard |
| Extended day plan | No | Yes | `require_feature(extended_forecast)` — `air.py` | DailyPlannerView / Android planner |
| Planner hourly | No | Yes | `require_feature(extended_forecast)` — `planner.py` | DailyPlannerView |
| Custom briefing schedule (PUT) | Read free | Write premium | `require_feature(custom_alerts)` — `briefings.py` PUT only | Settings briefing |
| GDPR privacy export | Yes | Yes | **Auth only** — `privacy.py` GET `/export` (no premium gate) | Settings export |
| Account deletion | Yes | Yes | **Auth only** — `privacy.py` POST `/delete-account` | Settings delete |
| Premium exportable reports | No | Yes | `export_reports_enabled` flag (future product surface) | TBD |
| Advanced insights | No | Yes | `require_feature(advanced_insights)` — `insights.py` | InsightsView |
| Daily recommendations | No | Yes | `require_feature` via daily rec — `recommendations.py` | Dashboard / insights |
| Wearable insights | No | Yes (future) | `wearable_insights_enabled` flag | TBD |
| Priority notifications | No | Yes (future) | `priority_notifications_enabled` flag | TBD |

## Test coverage (target)

| Case | Backend test module |
|------|---------------------|
| Free entitlement defaults | `test_subscriptions_entitlements.py` |
| iOS verify → premium | same |
| Expired iOS → free | same |
| Android verify / expire | same |
| Webhook idempotency / bad signature | `test_security_authz_guards.py` + entitlements tests |
| Stub activate blocked in production | `test_phase0_hardening.py` |
| Profile limit | entitlements tests |
| Premium endpoint 402 for free | entitlements tests |

Mobile: `HiAirTests/SubscriptionServiceTests.swift`, `SubscriptionBillingManagerTest.kt` (unit-level with test doubles).
