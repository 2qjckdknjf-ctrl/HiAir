# First 10 Users Launch Sprint

Goal: ship analytics, crash reporting, feedback, KPI dashboard, and store readiness for the first 10 real users. No new product features beyond launch instrumentation.

## Migrations (apply on staging Postgres)

From `backend/`:

```bash
psql "$DATABASE_URL" -f sql/006_wearable_metrics.sql
psql "$DATABASE_URL" -f sql/007_launch_analytics.sql
```

Rollback (if needed):

```bash
psql "$DATABASE_URL" -f sql/007_launch_analytics_rollback.sql
psql "$DATABASE_URL" -f sql/006_wearable_metrics_rollback.sql
```

## Staging validation

```bash
cd backend
python3 scripts/staging_launch_preflight.py --base-url "$HIAIR_STAGING_API_BASE_URL"
```

Covers: auth, dashboard, planner, morning briefing, risk breakdown, personal patterns, privacy export/delete, analytics ingest, feedback, crash report, KPI dashboard.

## Analytics events (mobile + backend)

- `onboarding_started`
- `onboarding_completed`
- `dashboard_opened`
- `morning_briefing_opened`
- `share_card_clicked`
- `symptom_logged`
- `privacy_export_requested`
- `privacy_delete_requested`
- `guest_mode_used`
- `feedback_submitted` (internal)
- `app_install_tracked` (internal, used for install proxy)

API: `POST /api/analytics/events` (guest-friendly), `GET /api/analytics/kpi-dashboard` (auth required).

## Crash monitoring

Backend endpoint: `POST /api/crashes/report`.

Mobile uses lightweight uncaught-exception reporters (Android `CrashReporter`, iOS `CrashReporter`) as a Firebase Crashlytics placeholder. Swap to Firebase SDK when Apple/Google credentials and SDK keys are configured.

## Feedback

Settings → **Send Feedback** (iOS + Android).

Fields: liked / confusing / broken + optional email.

API: `POST /api/feedback`.

## Device validation commands

### Android (macOS/Linux with SDK)

```bash
cd mobile/android
./gradlew assembleDebug assembleRelease lint test
```

### iOS (macOS with Xcode)

```bash
cd mobile/ios
xcodebuild -scheme HiAir -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme HiAir -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## TestFlight checklist

| Item | Status |
|------|--------|
| App icon in Xcode asset catalog | Required — verify on Mac |
| Screenshots (6.7", 6.5", iPad if supported) | Required — capture on device/simulator |
| Privacy Policy URL `https://hiair.app/privacy` | In-app link ready |
| Terms URL `https://hiair.app/terms` | In-app link ready |
| Release notes from `docs/release-notes-template.md` | Template ready |
| Archive + upload via Xcode Organizer | **BLOCKED** without Apple Developer credentials |
| Internal Testing group | **BLOCKED** without App Store Connect access |

## Google Play Internal Testing checklist

| Item | Status |
|------|--------|
| Release AAB `./gradlew bundleRelease` | Build on machine with SDK + signing |
| Screenshots (phone + optional tablet) | Required — capture on device |
| Feature graphic 1024×500 | Required — design asset |
| Privacy Policy URL | In-app + Play Console |
| Internal testing track + tester list | **BLOCKED** without Play Console credentials |

## KPI dashboard

`GET /api/analytics/kpi-dashboard?days=14` returns:

- installs (proxy via distinct sessions with install/onboarding events)
- onboarding completion rate
- D1 retention (onboarding_completed → dashboard_opened within 24h)
- morning briefing opens
- symptom logs
- share usage
- feedback submissions
- crash reports

Also exposed via Settings → **First-user KPI** button (Android/iOS) for operators with auth.

## Stop list (this sprint)

ML, AI prediction, Smart Home, Alexa, HomeKit automation, Community, Forum, B2B dashboards — out of scope.
