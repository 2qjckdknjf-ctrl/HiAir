# Android Release Signing Guide — HiAir

**Updated:** 2026-07-07 (Operator Certification Mission #3)  
**Application ID:** `com.hiair`  
**Current version:** `versionCode` 2 / `versionName` 0.1.0

Engineering has prepared the full release pipeline. **The agent must never auto-generate a production release keystore.** Only the app owner should create and custody upload keys.

---

## 1. What is already configured

| Item | Location | Status |
|------|----------|--------|
| Signing scaffold | `mobile/android/app/build.gradle.kts` | Ready |
| Example properties | `mobile/android/keystore.properties.example` | Ready |
| Gitignore | `keystore.properties`, `**/*.keystore` | Ready |
| Build script | `scripts/release/build_android_play_internal.sh` | Ready |
| Unsigned validation | `scripts/release/validate_store_release_builds.sh` | PASS |
| Signed validation | `scripts/release/validate_signed_android_release.sh` | Runs after keystore |
| Play upload script | `scripts/release/upload_play_internal.sh` | Ready (needs JSON key) |
| Full audit | `scripts/release/audit_android_release.sh` | Ready |

Release builds use `https://api.hiair.io`. Debug builds use emulator localhost only.

---

## 2. Owner: create release keystore (one-time)

Run on a **secure machine** (not in CI logs, never commit to git):

```bash
cd mobile/android

keytool -genkeypair -v \
  -keystore hiair-release.keystore \
  -alias hiair \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -storetype PKCS12
```

Record and store securely:

- Keystore file path (`hiair-release.keystore`)
- `storePassword`
- `keyAlias` (`hiair`)
- `keyPassword` (often same as store password)

**Backup:** Store encrypted copies in 1Password / Bitwarden / hardware vault. Loss of upload key requires Play Console key reset and may block updates.

---

## 3. Owner: configure `keystore.properties`

```bash
cd mobile/android
cp keystore.properties.example keystore.properties
```

Edit `keystore.properties`:

```properties
storeFile=hiair-release.keystore
storePassword=<your-store-password>
keyAlias=hiair
keyPassword=<your-key-password>
```

`storeFile` is resolved relative to **`mobile/android/`** (project root), not `app/`.

---

## 4. Build signed AAB

```bash
bash scripts/release/build_android_play_internal.sh
```

Output:

`mobile/android/app/build/outputs/bundle/release/app-release.aab`

---

## 5. Validate signed release

```bash
bash scripts/release/validate_signed_android_release.sh
bash scripts/release/audit_android_release.sh
```

Checks:

- `jarsigner -verify` on AAB
- Certificate SHA-1 / SHA-256 (for Play App Signing enrollment)
- Production API URL in DEX (no `10.0.2.2`)
- `versionCode`, `versionName`, `com.hiair`

---

## 6. Google Play App Signing

Recommended flow for new apps:

1. **First upload:** Use your **upload key** (the keystore you created above).
2. **Play App Signing:** Enroll when prompted in Play Console. Google holds the app signing key; you keep the upload key.
3. **SHA-256 for Play:** After first signed build, run:

   ```bash
   keytool -printcert -jarfile mobile/android/app/build/outputs/bundle/release/app-release.aab
   ```

4. If you lose the upload key, use Play Console → Setup → App signing → **Request upload key reset** (requires proof of ownership).

---

## 7. Upload to Internal Testing

### Option A — Script (service account)

1. Play Console → Setup → API access → link Google Cloud project
2. Create service account with **Release manager** (or Admin)
3. Save JSON to `backend/.secrets/google-play-service-account.json` (gitignored)
4. Install fastlane: `gem install fastlane` (or use manual upload)
5. Run:

   ```bash
   bash scripts/release/upload_play_internal.sh
   ```

### Option B — Manual (no service account)

1. Play Console → **Testing → Internal testing → Create release**
2. Upload `app-release.aab`
3. Release notes: `docs/release/store/RELEASE_NOTES.md`

---

## 8. Rollback plan

| Scenario | Action |
|----------|--------|
| Bad release on Internal track | Play Console → Internal testing → **Halt rollout** or promote previous release |
| Critical API regression | Roll back API via Cloudflare Containers deploy; Android app unchanged |
| Wrong AAB uploaded | Upload new AAB with **higher** `versionCode` (increment in `build.gradle.kts`) |
| Compromised upload key | Rotate keystore + Play upload key reset; never commit old key |

---

## 9. Security checklist

- [ ] Keystore and passwords **not** in git
- [ ] `keystore.properties` only on owner build machine
- [ ] Service account JSON in `backend/.secrets/` only
- [ ] CI does not embed signing secrets (local/owner build for now)

---

## Related docs

- `docs/release/GOOGLE_PLAY_INTERNAL_CHECKLIST.md`
- `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
- `docs/release/store/STORE_METADATA.md`
- `docs/release/MISSION3_OPERATOR_CERTIFICATION.md`
