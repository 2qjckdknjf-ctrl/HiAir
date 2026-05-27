# HiAir Brand Assets Manifest

Last updated: 2026-05-27

| Asset | Source | Output (iOS) | Output (Android) | Purpose | Size | Status | Referenced in |
|-------|--------|--------------|------------------|---------|------|--------|---------------|
| App icon | Placeholder vector | Assets.xcassets/AppIcon.appiconset | mipmap + adaptive icon | Launcher | 1024×1024 master | **placeholder** | Info.plist, AndroidManifest |
| HiAir Orb | Brand mockup PNG | HiAirOrb.imageset | drawable/hiair_orb.png | Hero, splash, auth, empty states | 128–384pt | **final (mockup extract)** | HiAirOrbLogoView, HiAirComponents |
| Logo mark | drawable | HiAirLogoMark.imageset | drawable/hiair_logo_mark.xml | Compact header | 48×48 | **placeholder** | HiAirBrandHeader |
| Wordmark | text + optional asset | HiAirWordmark.imageset | drawable/hiair_wordmark.xml | Splash, auth | scalable width | **text-primary** | LaunchScreen, AuthView |
| Launch logo | orb + wordmark | HiAirLaunchLogo.imageset | drawable/hiair_launch_logo.xml | Splash | 120×120 orb area | **placeholder** | LaunchScreen.storyboard |
| Mono light | vector | HiAirMonoLight.imageset | drawable/hiair_mono_light.xml | On dark bg | 48×48 | **placeholder** | Settings |
| Mono dark | vector | HiAirMonoDark.imageset | drawable/hiair_mono_dark.xml | On light bg (store) | 48×48 | **placeholder** | Store assets |
| AI guide avatar | PNG | HiAir/Assets/hiair-ai-guide-avatar.png | — | Insights guide | existing | **final** | InsightsView |
| Adaptive icon fg | vector | — | drawable/ic_hiair_launcher_foreground.xml | Android launcher | 108dp | **placeholder** | AndroidManifest |
| Adaptive icon bg | color | — | drawable/ic_hiair_launcher_background.xml | Android launcher | 108dp | **final** (#0E1226) | AndroidManifest |

## Manual replacement checklist

When final brand PNG/SVG exports arrive from design:

1. Replace `AppIcon.appiconset` with full icon set (20–1024pt)
2. Replace orb vector with final HiAir Orb artwork
3. Replace wordmark asset if typographic lockup differs from system text
4. Update this manifest status column to **final**

## Rules

- No full-screen marketing PNGs in screen folders
- UI backgrounds are token gradients, not bitmap posters
- All new assets must be listed here before merge
