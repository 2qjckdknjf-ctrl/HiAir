# Operator Certification Mission #4 — Keystore Investigation

**Date:** 2026-07-07  
**Verdict:** **WAITING ONLY FOR PROVEN MISSING RELEASE KEYSTORE** (on this machine)

---

## Investigation summary

Full search performed per Mission #4. **No HiAir release keystore file** and **no `keystore.properties`** exist on this workstation. **No Google Play service account JSON** in `backend/.secrets/`.

Belief that keystore "already exists" likely refers to **PR #27 signing scaffold** (`origin/cursor/android-play-publish-*`) which configured CI/env-var signing but **never placed key material in this repo clone**.

---

## Where we searched

| Location | Result |
|----------|--------|
| `mobile/android/keystore.properties` | **MISSING** |
| `mobile/android/hiair-release.keystore` | **MISSING** |
| `mobile/android/upload-keystore.jks` | **MISSING** |
| `mobile/android/.secrets/` | **MISSING** |
| `mobile/android/**/*.keystore`, `**/*.jks` | **0 files** |
| `backend/.secrets/` | Apple keys only; no Play JSON, no keystore |
| `~/.hiair-secrets/` | **Directory does not exist** |
| `.tools/` | Python + xcodegen only |
| `.cursor/` | No signing artifacts |
| Git stashes (4) | No keystore content |
| `backend/.env.local` | `GOOGLE_PLAY_PACKAGE_NAME` only; no `ANDROID_KEYSTORE_*` |
| macOS Keychain (`hiair`, `upload-keystore`) | **Not found** |
| `/Users/alex/Projects` (upload-keystore.jks) | Only **AISTROYKA** projects (different app) |
| Git history | Keystore **never committed** (gitignored by design) |

---

## Root cause (why Mission #1–3 missed it)

1. **Two signing conventions** in repo history:
   - **New (Mission #1–3):** `keystore.properties` + `hiair-release.keystore` + alias `hiair`
   - **Old (PR #27, not on current branch until Mission #4 restore):** `upload-keystore.jks` + env vars + alias `hiair-upload` + GitHub `ANDROID_KEYSTORE_BASE64`

2. Previous checks only tested **Convention A** paths in `mobile/android/`.

3. **Convention B** key material would live in GitHub **production** environment secrets or owner vault — **not verifiable locally** (`gh` is x86-only on this arm64 Mac).

4. **No wrong path bug** — files genuinely absent from disk.

---

## Fixes applied (Mission #4)

- Restored **dual-path signing** in `build.gradle.kts` (properties + env vars)
- Restored `.github/workflows/android-release.yml` for CI upload when secrets exist
- Added `scripts/release/investigate_android_keystore.sh`

---

## Owner actions

**If keystore exists elsewhere (password manager, another Mac, GitHub secrets):**

```bash
# Option A — properties file
cd mobile/android
cp keystore.properties.example keystore.properties
# point storeFile at your .keystore or .jks

# Option B — env vars (PR #27 style)
export ANDROID_KEYSTORE_PATH="/absolute/path/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="..."
export ANDROID_KEY_ALIAS="hiair-upload"
export ANDROID_KEY_PASSWORD="..."

bash scripts/release/build_android_play_internal.sh
bash scripts/release/validate_signed_android_release.sh
bash scripts/release/upload_play_internal.sh
```

**If keystore is only in GitHub:** Actions → Android Release → Run workflow (production environment secrets required).

**If keystore truly never existed:** generate once per `ANDROID_RELEASE_SIGNING_GUIDE.md` (owner-only).

---

## Final verdict

**WAITING ONLY FOR PROVEN MISSING RELEASE KEYSTORE**

After exhaustive search, HiAir release signing material is not present on this machine. Pipeline is ready for immediate sign+upload once owner supplies keystore (local file, env vars, or GitHub secrets).
