# HiAir Brand Assets Manifest

Last updated: 2026-05-28 (Logo Asset Lock)

| Asset | Source | Output (iOS) | Output (Android) | Purpose | Size | Status | Referenced in |
|-------|--------|--------------|------------------|---------|------|--------|---------------|
| App icon | `HiAir_logo_publish_pack` | `AppIcon.appiconset` (18 PNGs) | `mipmap-*` + `mipmap-anydpi-v26` | Launcher / store | 20–1024pt | **final** | Xcode catalog, `AndroidManifest` `@mipmap/ic_launcher` |
| HiAir Orb | Publish pack transparent PNG | `HiAirOrb.imageset` 128/256/512 | `drawable/hiair_orb.png` | Hero, weather, in-app orb | scalable | **final** | `HiAirOrbLogoView`, `brandOrbView`, splash layer |
| Logo mark | Publish pack square mark | `HiAirLogoMark.imageset` 64/128/256 | `drawable/hiair_logo_mark.png` | Compact header mark | 48dp max | **final** | `HiAirBrandHeader` compact, `brandLogoMarkView` |
| Wordmark | Publish pack light lockup | `HiAirWordmark.imageset` | `drawable/hiair_wordmark.png` | Auth, launch, full header | ~200×48dp | **final** | `HiAirBrandHeader`, `HiAirLaunchView`, `brandWordmarkView` |
| Launch logo | Large orb masters | `HiAirLaunchLogo.imageset` 256/512/1024 | `drawable/hiair_launch_logo.xml` → orb | Cold start / splash | 120dp | **final** | `LaunchScreen.storyboard`, `hiair_splash_background` |
| Mono light | Horizontal logo light | `HiAirMonoLight.imageset` | `drawable/hiair_mono_light.png` | Footer on dark UI | ~140×40pt | **final** | `HiAirBrandMonoFooter`, `brandMonoFooterView` |
| Mono dark | Horizontal logo dark | `HiAirMonoDark.imageset` | `drawable/hiair_mono_dark.png` | Store / light-bg export | 1600×480 master | **final (intentional non-UI)** | `docs/brand/store-assets/` export; lint ignored in-app (see below) |
| AI guide avatar | PNG | `hiair-ai-guide-avatar.png` | — | Insights guide | existing | **final** | `InsightsView` / Settings guide |
| Adaptive icon fg | Publish pack | — | `@mipmap/ic_launcher_foreground` | Android launcher safe zone | per density | **final** | `ic_launcher.xml` |
| Adaptive icon bg | Aurora gradient | — | `@drawable/ic_launcher_background` | Launcher background | 108dp | **final** | `ic_launcher.xml` |
| Play icon 512 | Publish pack | — | — | Google Play | 512×512 | **final** | `docs/brand/store-assets/google-play-icon-512.png` |
| Feature graphic | Publish pack | — | — | Google Play | 1024×500 | **final** | `docs/brand/store-assets/google-play-feature-graphic-1024x500.png` |

## Intentionally unused in runtime UI

| Asset | Reason |
|-------|--------|
| `hiair_mono_dark.png` (Android) | Light-background mono lockup for **marketing / Play Console / print**; app UI uses dark theme + `hiair_mono_light`. Kept in repo for publication bundle; `lint.xml` ignores `UnusedResources` for this file only. |
| `HiAirMonoDark.imageset` (iOS) | Same as above — available for App Store marketing assets, not shown in dark in-app chrome. |

## Removed (legacy placeholders)

- `drawable/hiair_logo_mark.xml`, `hiair_wordmark.xml`, `hiair_mono_*.xml` (vector placeholders)
- `drawable/ic_hiair_launcher*.xml/png` (superseded by `@mipmap/ic_launcher`)

## Rendering rules

- **iOS:** `.renderingMode(.original)`, `.scaledToFit()`, fixed frames use `min` / `max` — no template tint.
- **Android:** `imageTintList = null`, `ScaleType.FIT_CENTER`, splash via `hiair_launch_logo` layer-list (120dp, centered).
- **Launcher:** square App Icon ≠ orb header ≠ wordmark ≠ mono footer.

## Manual replacement checklist

All publication-critical assets are **final** from `HiAir_logo_publish_pack`. Future brand refresh: replace PNGs in both platforms + `docs/brand/store-assets/`, then update this manifest date.

## Rules

- No full-screen marketing PNGs in screen folders
- UI backgrounds are token gradients, not bitmap posters
- All new assets must be listed here before merge
