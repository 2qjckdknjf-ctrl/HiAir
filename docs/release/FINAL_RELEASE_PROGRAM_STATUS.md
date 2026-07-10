# HiAir — Final Release Program Status

**Updated:** 2026-07-10  
**Verdict:** **TESTFLIGHT READY — PLAY INTERNAL WAITING FOR OWNER**

---

## Store certification (2026-07-10)

| Track | Status | Evidence |
|-------|--------|----------|
| TestFlight (iOS) | **READY** | ASC build 65 VALID |
| Play Internal (Android) | **BLOCKED** | Signed AAB PASS; no `com.hiair` in Play Console; no API JSON |

Signed AAB: `mobile/android/app/build/outputs/bundle/release/app-release.aab` (versionCode 2, `com.hiair`)

---

## Engineering closed

| Area | Status | Evidence |
|------|--------|----------|
| Production API (`api.hiair.io`) | LIVE | health 200; `source=sample` 200; Castelldefels `environmental.source=live` |
| Environment resolver | LIVE | live → cached → sample; Open-Meteo default |
| Backend pytest | PASS | 119 tests |
| Android build/lint/tests | PASS | release APK at `mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk` |
| iOS build/tests | PASS | 4/4; Release → `https://api.hiair.io` |
| Production fake UI | REMOVED | No Barcelona/Alex/fake actions in mobile production paths |
| Privacy export (GDPR baseline) | DEPLOYED | Premium gate removed; `GET /api/privacy/export` → 401 without auth (not 402) |
| Search audit | PASS | No production fake strings in `.kt`/`.swift` app code |

## Operator certification required

| Area | Status | Owner action |
|------|--------|--------------|
| Device QA (Android) | BLOCKED | Install **release** APK; adb + USB device |
| Device QA (iPhone) | BLOCKED | Device `00008150-001E4C911100C01C` offline; TestFlight or USB |
| iPad | NOT STARTED | — |
| TestFlight upload | PENDING | Xcode archive + ASC |
| Play Internal Testing | PENDING | Signed AAB + Play Console |
| Sandbox IAP verification | PENDING | On-device purchase proof |
| Push notifications on device | PENDING | Wire `registerDeviceToken` + APNs/FCM |

## Release configuration

| Build | API base |
|-------|----------|
| Android debug | `http://10.0.2.2:8000` |
| Android release | `https://api.hiair.io` |
| iOS debug | `http://127.0.0.1:8000` |
| iOS release | `https://api.hiair.io` |

Device certification against production **must use release builds**.

## Commits on `main`

- `e02e4dd` — privacy export gate removal + dead mock client + status doc
- `b96ea18` — RC-2 fake UI removal + iOS tests
- `a2123fe` — live environmental backend deploy
