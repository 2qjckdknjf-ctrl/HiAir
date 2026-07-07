# Operator Certification Mission #3 — Android Release Signing → Play Internal

**Date:** 2026-07-07  
**Branch:** `main`  
**iOS status:** TestFlight build **65 VALID** — READY FOR TESTFLIGHT  
**Android status:** Pipeline **READY** — **WAITING ONLY FOR RELEASE KEYSTORE** (+ Play upload credentials)

---

## Executive summary

Mission #3 completed all engineering stages that do not require owner secrets:

- Full Android release audit (build.gradle, manifest, permissions, Health Connect, notifications)
- Fixed `storeFile` path resolution (`rootProject.file` — keystore at `mobile/android/`)
- Added Health Connect Play compliance (`VIEW_PERMISSION_USAGE` + permissions rationale)
- Signed validation script, full audit script, owner signing guide
- Unsigned AAB builds; production API validation PASS
- Play Internal upload script and rollback plan documented

**Single engineering blocker for Play Internal:** owner must supply `mobile/android/keystore.properties` + release keystore. Optional: `backend/.secrets/google-play-service-account.json` for automated upload.

**Store assets:** screenshots and feature graphic still **MISSING** (owner) — does not block Internal Testing upload but required before production listing.

---

## Stage results

| Stage | Result |
|-------|--------|
| 1 — Android release audit | PASS (fixes applied) |
| 2 — Release keystore | BLOCKED — owner only (not auto-created) |
| 3 — Signed release validation | Script ready; blocked on keystore |
| 4 — Google Play Internal | Script ready; blocked on keystore + Play JSON |
| 5 — Store assets | Draft metadata ready; graphics MISSING |
| 6 — Release verification | Unsigned AAB PASS (api.hiair.io, no debug URLs) |
| 7 — Documentation | Updated |

---

## Owner next steps (minimal path to Play Internal)

```bash
# 1. Keystore (see ANDROID_RELEASE_SIGNING_GUIDE.md)
cd mobile/android && cp keystore.properties.example keystore.properties
# ... generate hiair-release.keystore, edit properties ...

# 2. Build + validate
bash scripts/release/build_android_play_internal.sh
bash scripts/release/validate_signed_android_release.sh

# 3. Upload (manual or script)
bash scripts/release/upload_play_internal.sh
# OR upload AAB manually in Play Console → Internal testing
```

---

## Verdict

**WAITING ONLY FOR RELEASE KEYSTORE**

All other Android release pipeline components are verified ready. iOS TestFlight is already VALID. After owner keystore + Play upload, status becomes **READY FOR BOTH STORES** (Internal Testing tracks).
