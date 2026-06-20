# HiAir Android Play Publish Setup

This guide configures automated upload of signed Android App Bundles (AAB) to Google Play.

## Prerequisites

1. Google Play Console app entry for package `com.hiair`.
2. Play Console access for the Product/Founder owner (external blocker EXT-002).
3. Upload keystore generated and registered in Play Console.
4. Google Cloud service account with Play Developer API access.

## 1. Create upload keystore

From repository root:

```bash
bash mobile/android/scripts/generate_upload_keystore.sh mobile/android/upload-keystore.jks hiair-upload
```

Keep the keystore file outside git. The script prints the base64 command for CI secrets.

## 2. Configure Google Play service account

1. In Google Play Console: Setup -> API access.
2. Link a Google Cloud project (or create one).
3. Create a service account and grant Play Console user with release permissions.
4. Download the service account JSON key.

Required API: Google Play Android Developer API.

## 3. Add GitHub repository secrets

| Secret | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore (`.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias (default: `hiair-upload`) |
| `ANDROID_KEY_PASSWORD` | Key password |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Full JSON content of service account key |

Generate base64 keystore payload:

```bash
base64 -w 0 mobile/android/upload-keystore.jks
```

## 4. Publish from GitHub Actions

Workflow: `.github/workflows/android-release.yml`

Manual run:
1. GitHub -> Actions -> Android Release -> Run workflow.
2. Choose track (`internal` recommended for first upload).
3. Optionally set `version_name` (defaults to `0.1.<run_number>`).

Tag trigger (optional):

```bash
git tag android/v0.1.0
git push origin android/v0.1.0
```

Tag pushes publish to the `internal` track by default.

## 5. Post-publish verification

1. Confirm release appears in Play Console internal testing track.
2. Add testers and verify install on a physical device.
3. Execute `docs/qa-checklist.md`.
4. Attach upload evidence to external blocker issue EXT-002.

## Local signed release build (optional)

```bash
export ANDROID_KEYSTORE_PATH="/absolute/path/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="..."
export ANDROID_KEY_ALIAS="hiair-upload"
export ANDROID_KEY_PASSWORD="..."
export ANDROID_VERSION_CODE=2
export ANDROID_VERSION_NAME="0.1.2"

cd mobile/android
./gradlew :app:bundleRelease --no-daemon
```

Output:
`mobile/android/app/build/outputs/bundle/release/app-release.aab`

## Notes

- CI uses `github.run_number` as monotonic `versionCode`.
- Release builds without signing env vars still compile locally/CI using debug signing (not Play-ready).
- Manual upload fallback remains documented in `docs/store-upload-last-mile.md`.
