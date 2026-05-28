# HiAir Logo Assets Fix Report

Branch: `fix/hiair-logo-assets-display`  
Date: 2026-05-28  
Source pack: `HiAir_logo_publish_pack.zip` (from Downloads)

## Problems found (audit)

| Area | Issue |
|------|--------|
| **iOS AppIcon** | `AppIcon.appiconset` contained only a single `1024x1024` universal entry — missing required iPhone/iPad sizes (120, 152, 167, etc.). |
| **iOS in-app assets** | `HiAirLogoMark`, `HiAirWordmark`, `HiAirLaunchLogo` imagesets had `Contents.json` but **no PNG files** (broken/empty catalogs). |
| **iOS HiAirOrb** | Present but generated from older pipeline; replaced with publish-pack transparent orb masters. |
| **iOS rendering** | `Image("HiAirOrb")` had no `.renderingMode(.original)` — risk of template/tint on some contexts. |
| **Android launcher** | Manifest pointed at `@drawable/ic_hiair_launcher` (placeholder vector “HI” glyph), not real orb icon. |
| **Android mipmaps** | No `mipmap-*` density folders — only legacy `ic_hiair_*` drawables. |
| **Android in-app orb** | `hiair_orb.png` was outdated; `hiair_logo_mark.xml` / `hiair_wordmark.xml` were vector placeholders, not brand PNGs. |
| **Store assets** | Google Play 512 icon and 1024×500 feature graphic were not in repo. |

## Assets replaced / added

### iOS (`mobile/ios/HiAir/Assets.xcassets/`)

- **AppIcon.appiconset** — full copy from pack `02_ios/AppIcon.appiconset` (18 PNGs + `Contents.json`).
- **HiAirOrb.imageset** — `128 / 256 / 512` px orb (1x/2x/3x).
- **HiAirLogoMark.imageset** — square mark `64 / 128 / 256` (1x/2x/3x).
- **HiAirLaunchLogo.imageset** — large orb `256 / 512 / 1024` for launch/splash contexts.
- **HiAirWordmark.imageset** — light wordmark lockup `400 / 800 / 1200` px wide (from `hiair-wordmark-light-transparent-1200x320.png`).

### Android (`mobile/android/app/src/main/res/`)

- **mipmap-mdpi … xxxhdpi** — `ic_launcher`, `ic_launcher_round`, `ic_launcher_foreground`.
- **mipmap-anydpi-v26** — adaptive `ic_launcher.xml`, `ic_launcher_round.xml`.
- **drawable/ic_launcher_background.xml** — aurora gradient background (safe zone).
- **drawable/hiair_orb.png** — replaced from `hiair_orb_512.png`.

### Docs / store (`docs/brand/store-assets/`)

- `google-play-icon-512.png`
- `google-play-feature-graphic-1024x500.png`

## Code / reference fixes

| File | Change |
|------|--------|
| `HiAirComponents.swift` | `.renderingMode(.original)` on `Image("HiAirOrb")`. |
| `HiAirLaunchView.swift` | In-app launch uses `HiAirLaunchLogo` asset (original rendering, aspect-fit 120pt). |
| `HiAirComponents.kt` | `imageTintList = null` on `brandOrbView` so full-color orb is not tinted. |
| `AndroidManifest.xml` | `android:icon` / `roundIcon` → `@mipmap/ic_launcher` / `@mipmap/ic_launcher_round`. |

**Unchanged:** LaunchScreen.storyboard still references `HiAirOrb` (updated asset catalog). Auth/Dashboard headers use `HiAirOrbLogoView` → `HiAirOrb` asset.

## AppIcon sizes (iOS) — acceptance

| Required | File in set | Pixel size |
|----------|-------------|------------|
| iPhone 120×120 | `Icon-App-60x60@2x.png` | 120 |
| iPad 152×152 | `Icon-App-76x76@2x.png` | 152 |
| iPad Pro 167×167 | `Icon-App-83.5x83.5@2x.png` | 167 |
| Marketing 1024×1024 | `Icon-App-1024x1024@1x.png` | 1024 (opaque, no alpha) |

All filenames in `Contents.json` verified present on disk.

## Android adaptive icon

- **Foreground:** `@mipmap/ic_launcher_foreground` (transparent orb, per-density).
- **Background:** `@drawable/ic_launcher_background` (gradient shape).
- **Legacy mipmaps:** included for API &lt; 26.

After install, **uninstall the app** on device/emulator if the home-screen icon still shows the old placeholder (launcher cache).

## Build commands & results

```bash
cd mobile/android && ./gradlew :app:assembleDebug
# BUILD SUCCESSFUL

cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' \
  build CODE_SIGNING_ALLOWED=NO
# BUILD SUCCEEDED
```

## Not touched (per scope)

Backend, API, auth, Supabase, data models, risk engine, navigation contracts, notifications, permissions, subscriptions, analytics, persistence, business logic.

## Manual follow-up

1. Delete app from simulator/device and reinstall to refresh launcher icon.
2. Xcode: Product → Clean Build Folder if asset catalog appears stale.
3. App Store Connect: upload build with new `AppIcon.appiconset`.
4. Google Play Console: upload `docs/brand/store-assets/google-play-icon-512.png` and feature graphic.
5. Optional: wire `HiAirWordmark` / `HiAirLogoMark` in UI where text+orb lockups are desired (assets are ready; headers still use orb + `Text("HiAir")`).
