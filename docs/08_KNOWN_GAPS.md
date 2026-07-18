# 08 Known Gaps

Updated: 2026-07-18 (StoreKit Request Canceled on build 81)

## P0 (block first 10 real users)

- **StoreKit catalog FAIL on physical iPhone (build 81):** UI shows unavailable + **Request Canceled**; no prices; no purchase sheet. Fix build **82**. Owner must also confirm Paid Apps Agreement Active. See `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.
- **Prior build 80:** prices missing / Subscribe dead (observation/UX).
- **Prior build 79:** password authentication loop.
- **Physical iPhone session STARTED** — certification no longer "not run".
- **Use release mobile builds against production** — debug variants point to localhost (`10.0.2.2` / `127.0.0.1`).
- **Guest mode not implemented** on iOS or Android (auth wall for all features).
- **Push notifications not wired on mobile** — `registerDeviceToken` exists in API clients but is never called; Morning Briefing UI without verified APNs/FCM delivery on device. (Sequenced AFTER live data + device QA.)
- **No dedicated crash SDK** (Crashlytics/Sentry); relies on ASC/Play console symbolicated crashes only.
- **Manual end-to-end QA not completed** — RC-1 unblocked; owner hardware session pending for RC-2.
- **Android Play release signing** not configured in Gradle (unsigned `app-release-unsigned.apk` only).
- **Auto-created profiles use coordinates 0,0** — **FIXED (2026-07-14)** Android/iOS bootstrap now requires valid device coordinates; backend rejects `(0,0)`.

## P1 (important before wider beta)

- **Share flow missing** on iOS and Android (no share sheet / export file handoff for privacy export).
- **Privacy export UX** shows section count only; does not produce shareable file on iOS/Android.
- **es/it/fr localization incomplete** on both mobile platforms (partial overrides; OAuth labels and ViewModel strings still English).
- **Production API cold-start latency ~4s** on first `GET /api/health` (2026-06-29); warm hits 0.24–0.63s. Confirmed Cloudflare Containers cold start (not constant latency); consider min-instance warm-up or scheduled ping if first-hit UX matters.
- **Product analytics** wired via OS logger only (`ProductAnalytics`); no remote aggregation dashboard yet. Events: `onboarding_*`, `dashboard_opened`, `morning_briefing_viewed`, `risk_breakdown_viewed`, `symptom_logged`, `privacy_export`, `privacy_delete` — **not wired:** `share_clicked`, `guest_mode` (features absent).
- **Android onboarding flow** not implemented (removed dead `OnboardingState`; no first-run wizard).
- **Settings dev surfaces** expose raw tokens/userId in production UI (iOS Settings, Android Settings).

## Engineering closed in MEGA SPRINT #2

- Backend: fixed legacy `/api/risk/estimate` Response shadowing bug; deduplicated air score helpers; planner uses authenticated `user_id`; removed unused imports; README auth docs corrected; pyflakes clean.
- Android: removed dead navigation/onboarding files; fixed billing deprecated API; fixed Supabase type mismatch; added missing L10n keys; **assembleDebug/Release + lint + unit tests PASS**.
- iOS: removed unused Supabase SPM dependency (~9s faster clean build); fixed WearableConsentView force-unwrap crash; added ProductAnalytics; **xcodebuild build + 4 tests PASS**.

## Engineering closed in P0 Sprint #1 (Android live dashboard, `205beed`)

- Removed all hardcoded/demo dashboard content (location, greeting, weather, fake risk gauge, static safe windows, action tiles).
- Dashboard driven by a single state machine (Initial/Loading/Success/Empty/Error/Offline) fed only by `/api/air/current-risk`; loading/error/offline + Retry; auto profile bootstrap via `/api/profiles`.
- Removed dead/legacy API methods; analytics `dashboard_loading/loaded/failed/retry`.

## Engineering closed in P0 Sprint #2 (live environmental backend, `631fb2e`)

- Unified resolver `air_environment_service.resolve_environment_snapshot`: live providers (Open-Meteo default, no API key) → DB cache (15m TTL, geo-hash) → sample fallback; honest `source` labeling.
- Wired `/api/air/current-risk`, day-plan, recommendations, dashboard, planner, morning briefing through the resolver; snapshots persisted on compute and re-read from cache on provider failure.
- Source label (Live/Cached/Sample) shown on Android + iOS dashboards.
- **Backend validation (local, 2026-06-29): `compileall` OK, `pytest` 119 passed, `validate_risk_historical` 4/4. `check_env_security --strict` fails only on `JWT_SECRET` absent from shell env (lives in `.env.local`) = EXPECTED LOCAL.**

## External Blockers

- APNs production keys and FCM production credentials.
- Apple/Google store console publishing actions (signed artifacts, IAP prices, review screenshots).
- Final legal review/sign-off and public policy URL publication.
- On-device sandbox IAP verification (status remains **ARCHITECTURE READY**, not STORE SANDBOX READY).
