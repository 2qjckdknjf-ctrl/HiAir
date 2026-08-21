# 08 Known Gaps

Updated: 2026-08-21 (design/redesign-v4-deep-glass aligned for 1.0 / 188 ship PR)

## P0 (block first 10 real users)

- **Physical Runtime UX retest pending:** redesign line is now code-aligned to **iOS 1.0 (188)**, but the last proven Apple upload is still **181**; city / Health revoke / Premium matrix still **NOT RUN** on physical iPhone for the ship line.
- **Physical HealthKit / Health Connect E2E pending:** synthetic health smoke PASS; device matrices still **NOT RUN**.
- **Maestro physical iOS automation tooling:** driver build/connect flaky on Maestro 2.7 + Xcode 26.6 — not a product FAIL; blocks unattended UI certification.
- **StoreKit sandbox purchase:** retest on real TestFlight **188** after upload. Confirm Paid Apps Agreement / Tax / Banking Active if catalog empty.
- **Android physical + Play Billing:** Play Internal **188** exists, but no physical Android verification happened in this session.
- **Cloudflare CI credential durability:** prefer long-lived Custom API Token (runbook).
- **Use release / TestFlight builds against production** — debug variants point to localhost.
- **Push notifications not wired on mobile** — sequenced after device QA.

## Closed this pass (ship prep on 2026-08-21)

- Untracked Dashboard Health sync → cancellable coordinator.
- Local durable consent cleared before remote revoke/delete await.
- Premium rollback notifications account-attributed.
- iOS source-of-truth aligned to **1.0 (188)** in tracked project files.
- Store packet refreshed to current truth: Play Internal **188** today; last proven Apple upload **181**; owner-only store/legal/secrets tasks explicit.

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
