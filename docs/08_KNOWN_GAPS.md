# 08 Known Gaps

Updated: 2026-06-29 (MEGA SPRINT #2 audit)

## P0 (block first 10 real users)

- **Android dashboard first paint uses mock/static content** until manual refresh; not API-backed on cold start.
- **Guest mode not implemented** on iOS or Android (auth wall for all features).
- **Push notifications not wired on mobile** — `registerDeviceToken` exists in API clients but is never called; Morning Briefing UI without verified APNs/FCM delivery on device.
- **No dedicated crash SDK** (Crashlytics/Sentry); relies on ASC/Play console symbolicated crashes only.
- **Manual end-to-end QA not completed** in this sprint (install → auth → dashboard → privacy export/delete on physical devices).
- **Android Play release signing** not configured in Gradle (unsigned `app-release-unsigned.apk` only).

## P1 (important before wider beta)

- **Share flow missing** on iOS and Android (no share sheet / export file handoff for privacy export).
- **Privacy export UX** shows section count only; does not produce shareable file on iOS/Android.
- **es/it/fr localization incomplete** on both mobile platforms (partial overrides; OAuth labels and ViewModel strings still English).
- **Production API cold health latency ~4s** observed on `GET /api/health` (2026-06-29); investigate Cloudflare Containers warm-up.
- **Product analytics** wired via OS logger only (`ProductAnalytics`); no remote aggregation dashboard yet. Events: `onboarding_*`, `dashboard_opened`, `morning_briefing_viewed`, `risk_breakdown_viewed`, `symptom_logged`, `privacy_export`, `privacy_delete` — **not wired:** `share_clicked`, `guest_mode` (features absent).
- **Android onboarding flow** not implemented (removed dead `OnboardingState`; no first-run wizard).
- **Settings dev surfaces** expose raw tokens/userId in production UI (iOS Settings, Android Settings).

## Engineering closed in MEGA SPRINT #2

- Backend: fixed legacy `/api/risk/estimate` Response shadowing bug; deduplicated air score helpers; planner uses authenticated `user_id`; removed unused imports; README auth docs corrected; **115 pytest passed**, pyflakes clean.
- Android: removed dead navigation/onboarding files; fixed billing deprecated API; fixed Supabase type mismatch; added missing L10n keys; **assembleDebug/Release + lint + unit tests PASS**.
- iOS: removed unused Supabase SPM dependency (~9s faster clean build); fixed WearableConsentView force-unwrap crash; added ProductAnalytics; **xcodebuild build + 4 tests PASS**.

## External Blockers

- APNs production keys and FCM production credentials.
- Apple/Google store console publishing actions (signed artifacts, IAP prices, review screenshots).
- Final legal review/sign-off and public policy URL publication.
- On-device sandbox IAP verification (status remains **ARCHITECTURE READY**, not STORE SANDBOX READY).
