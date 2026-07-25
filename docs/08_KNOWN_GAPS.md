# 08 Known Gaps

Updated: 2026-07-25 (PR #34 Runtime UX Recovery merged · TF 127)

## P0 (block first 10 real users)

- **Physical Runtime UX retest pending:** PR #34 merged (`cda6722`); TestFlight **127** VALID («Первый»); city / Health revoke / Premium matrix still **NOT RUN** on physical iPhone. See `docs/audit/P0_RUNTIME_UX_RECOVERY.md`.
- **Physical HealthKit / Health Connect E2E pending:** synthetic health smoke PASS; device matrices still **NOT RUN**.
- **Maestro physical iOS automation tooling:** driver build/connect flaky on Maestro 2.7 + Xcode 26.6 — not a product FAIL; blocks unattended UI certification.
- **StoreKit sandbox purchase:** retest on **TF 127**. Confirm Paid Apps Agreement / Tax / Banking Active if catalog empty.
- **Android physical + Play Billing:** no USB device this session; Play Console app for `com.hiair` EXTERNALLY BLOCKED.
- **Cloudflare CI credential durability:** prefer long-lived Custom API Token (runbook).
- **Use release / TestFlight builds against production** — debug variants point to localhost.
- **Push notifications not wired on mobile** — sequenced after device QA.

## Closed this pass (PR #34)

- Untracked Dashboard Health sync → cancellable coordinator.
- Local durable consent cleared before remote revoke/delete await.
- Premium rollback notifications account-attributed.
- Fresh iOS CI + Security + Xcode Cloud green; PR merged; TF **127** distributed.

## P1 (important before wider beta)

- **Share flow missing** on iOS and Android.
- **Privacy export UX** section count only; no shareable file handoff.
- **es/it/fr localization incomplete** in places.
- **Production API cold-start** on first hit after idle.
- **Product analytics** OS logger only (no remote dashboard).

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
