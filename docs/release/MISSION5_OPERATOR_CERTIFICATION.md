# Operator Certification Mission #5 — Google Play Internal Upload

**Date:** 2026-07-10  
**Verdict:** **WAITING ONLY FOR PLAY CONSOLE OWNER ACTION**

---

## Summary

Signed AAB validated locally (**PASS**). Automated upload **not executed** — no Play Developer API credentials. Play Console browser session confirmed: **HiAir (`com.hiair`) app does not exist** in developer account `6120473136332405670` (only AiStroyka apps listed).

---

## Signed AAB validation (2026-07-10)

| Check | Result |
|-------|--------|
| AAB present | PASS |
| jarsigner | PASS |
| package | `com.hiair` |
| versionCode | 2 |
| versionName | 0.1.0 |
| Production API | PASS (`https://api.hiair.io`) |
| Debug localhost | absent |
| Upload SHA-1 | `8A:60:8E:E1:00:D1:54:89:17:76:01:23:65:1C:6A:A9:74:BC:21:DE` |
| Upload SHA-256 | `C7:BD:C2:1E:54:1F:88:76:07:6C:EB:65:3D:B6:C1:7D:30:86:DF:3F:6C:AA:E1:55:9A:D1:CA:96:9F:24:B3:FB` |

Artifact: `mobile/android/app/build/outputs/bundle/release/app-release.aab`

---

## Upload path investigation

| Path | Status |
|------|--------|
| `backend/.secrets/google-play-service-account.json` | **MISSING** |
| GitHub production `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | **MISSING** |
| GitHub `ANDROID_KEYSTORE_*` secrets | **MISSING** |
| Fastlane | not installed |
| Python Play API (`upload_play_internal.py`) | ready (needs JSON) |
| Play Console interactive session | **LOGGED IN** — no `com.hiair` app |

---

## Owner actions (exact order)

### 1. Create Play Console app (required first)

1. [Play Console](https://play.google.com/console/u/0/developers/6120473136332405670/app-list) → **Создать приложение**
2. App name: **HiAir**
3. Default language: English (or Russian)
4. App / Game: **App**
5. Free / Paid: **Free**
6. Accept declarations → Create
7. Confirm package name **`com.hiair`** matches signed AAB

### 2. Upload Internal testing release (manual)

1. HiAir → **Testing → Internal testing**
2. **Create new release**
3. Upload: `mobile/android/app/build/outputs/bundle/release/app-release.aab`
4. Release notes: `docs/release/store/RELEASE_NOTES.md` (0.1.0-beta section)
5. **Review release → Start rollout to Internal testing**

### 3. Optional — enable automated uploads

1. Play Console → **Setup → API access** → link Google Cloud project
2. Service account → **Release manager** on Play Console
3. Download JSON → `backend/.secrets/google-play-service-account.json` (gitignored)
4. Run: `bash scripts/release/upload_play_internal.sh`

### 4. Post-upload verification

- Setup → **App integrity** → verify upload certificate SHA-1 matches above
- Internal testing → confirm versionCode **2** processing
- Add internal testers + copy opt-in link
- Complete Data safety, content rating, store listing (may block rollout)

---

## Play Console evidence

- Developer account: Aleksandr Potkin (`6120473136332405670`)
- App list URL: https://play.google.com/console/u/0/developers/6120473136332405670/app-list
- Search `com.hiair`: **no results** (2026-07-10)

---

## iOS status (unchanged)

TestFlight build **65** — **VALID** → TestFlight track ready.
