# HiAir Logo Asset Lock — Final Report

Date: 2026-05-28  
Branch: `main` (post brand kit + publish pack merge)  
Scope: **logo / publication assets / rendering only**

## Executive summary

Publication-critical logo assets are **final** (no placeholders). All previously unused Android drawables are **wired** or **documented**. iOS and Android builds pass after lock.

## Placeholders replaced

| Was placeholder | Now |
|-----------------|-----|
| `HiAir-brand-assets-manifest.md` App icon, logo mark, launch, mono, adaptive fg | **final** publish pack |
| Android `hiair_logo_mark.xml` / `hiair_wordmark.xml` vectors | **PNG** from pack / iOS finals |
| Android `hiair_mono_*.xml` vectors | **PNG** horizontal lockups |
| Android `ic_hiair_launcher*` legacy | **removed**; `@mipmap/ic_launcher` only |
| iOS `HiAirMonoLight` / `HiAirMonoDark` empty imagesets | **PNG** populated |
| iOS header text-only “HiAir” | **HiAirWordmark** + compact **HiAirLogoMark** |

## Remaining non-runtime assets (documented, not placeholders)

| Asset | Why kept | Lint |
|-------|----------|------|
| `hiair_mono_dark.png` | Play / light-background marketing export | `lint.xml` `UnusedResources` ignore with manifest note |
| `HiAirMonoDark.imageset` | Same for iOS marketing | Not referenced in UI (by design) |

## Asset usage map

### Launcher

| Platform | Asset | Reference |
|----------|-------|-----------|
| iOS | `AppIcon.appiconset` | Xcode `ASSETCATALOG_COMPILER_APPICON_NAME` |
| Android | `@mipmap/ic_launcher` / `ic_launcher_round` | `AndroidManifest.xml` |
| Android fg/bg | `ic_launcher_foreground` + `ic_launcher_background` | `mipmap-anydpi-v26/ic_launcher.xml` |

### Splash / launch

| Platform | Asset | Reference |
|----------|-------|-----------|
| iOS | `HiAirLaunchLogo` | `LaunchScreen.storyboard`, `HiAirLaunchView` |
| iOS | `HiAirWordmark` | `HiAirLaunchView` (below orb) |
| Android | `hiair_launch_logo` → `hiair_orb` | `hiair_splash_background.xml` → `Theme.HiAir` |

### In-app header / auth

| Screen | iOS | Android |
|--------|-----|---------|
| Auth | `HiAirBrandHeader` (orb + wordmark) | `SettingsScreenRenderer` `brandHeader` (auth card area) |
| Onboarding | `HiAirBrandHeader` | — |
| Dashboard | `HiAirBrandHeader` compact/full | `DashboardScreenRenderer` `brandHeader` |
| Planner / Insights / Symptoms | — | `brandHeader` in renderers |
| Settings | `HiAirBrandHeader` (auth section) + mono footer | `brandHeader` + `brandMonoFooterView` |

### In-app orb (non-square)

| Use | iOS | Android |
|-----|-----|---------|
| Hero / gauge context | `HiAirOrbLogoView` → `HiAirOrb` | `brandOrbView` → `hiair_orb` |
| Weather chip | `HiAirOrbLogoView` | `brandOrbView` |

### Settings footer

| Platform | Asset |
|----------|-------|
| iOS | `HiAirMonoLight` via `HiAirBrandMonoFooter` |
| Android | `hiair_mono_light` via `brandMonoFooterView` |

## Rendering fixes applied

- **iOS:** `.renderingMode(.original)` on all brand `Image` assets; `.scaledToFit()`; compact mark capped at 48pt.
- **Android:** `imageTintList = null`; `FIT_CENTER` / `adjustViewBounds`; splash orb in 120dp centered bitmap layer (no crop).

## Verification paths

| Check | Path / command |
|-------|----------------|
| iOS screenshots | `docs/brand/screenshots/ios/{compact,standard,large,tablet}/dashboard.png` |
| Capture script | `scripts/capture_hiair_adaptive_qa.sh` |
| Store graphics | `docs/brand/store-assets/google-play-icon-512.png`, `google-play-feature-graphic-1024x500.png` |
| Asset manifest | `docs/brand/HiAir-brand-assets-manifest.md` |
| Prior integration | `docs/brand/HiAir-logo-assets-fix-report.md` |

## Build commands & results

```bash
cd mobile/android && ./gradlew clean :app:assembleDebug
# BUILD SUCCESSFUL

cd mobile/android && ./gradlew :app:lintDebug
# 0 errors; UnusedResources: hiair_mono_dark ignored per lint.xml

cd mobile/ios && xcodebuild -scheme HiAir -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build CODE_SIGNING_ALLOWED=NO
# BUILD SUCCEEDED
```

## Not changed

Backend, API, auth logic, Supabase, data models, risk engine, navigation contracts, notifications, subscriptions, analytics, persistence, business logic.

## Post-install note

Delete the app from simulator/device before verifying launcher icon (OS launcher cache).
