# Deep Glass V4 — Canonical Design Direction (RC worktree)

**Status:** selective integration in progress (not pixel-canonical to unreleased design branch)  
**Visual direction:** Deep Glass V4  
**UX/accessibility foundation:** Aurora Calm v2  
**Source reference (read-only):** `/Users/alex/Projects/HIAir` @ `design/redesign-v4-deep-glass`

## Principles

1. **Foreground never blurred** — glass/blur applies to navigation chrome and surfaces only.
2. **Reduce Transparency fallback** — `hiAirGlassSurface` degrades to opaque `Surface.bg3` + border.
3. **Spectrum accents** — cyan `#1AE8FF`, electric blue `#4D8CFF`, violet `#A06AFF`, magenta `#E05CFF`.
4. **Typography** — semantic styles + `hiAirFont(_:)` / `HiAirTypography.font(_:sizeCategory:)` for Dynamic Type.
5. **Touch targets** — minimum 44×44 pt on primary navigation and CTAs.
6. **Platform-native** — floating tab bar on iOS; Material/Compose tokens on Android (not mechanical iOS clone).

## Token map (iOS)

| Token | Location |
|-------|----------|
| Colors / Spectrum | `mobile/ios/HiAir/DesignSystem/HiAirColors.swift` |
| Glass surfaces | `mobile/ios/HiAir/DesignSystem/HiAirGlassSurface.swift` |
| Gradients | `mobile/ios/HiAir/DesignSystem/HiAirGradients.swift` |
| Radius / motion / shadow | `HiAirRadius`, `HiAirMotion`, `HiAirShadow` |
| Navigation | `HiAirFloatingTabBar.swift` + `RootTabView.swift` |

## Screenshot evidence policy

| Path | Purpose |
|------|---------|
| `docs/brand/store-assets/asc-screenshots/captured-iphone/` | ASC product screenshots (generated via `StoreScreenshotTests`) |
| `docs/brand/store-assets/asc-screenshots/captured-iphone-rc/` | RC QA captures (explicit `HIAIR_SCREENSHOT_OUT`) |
| `docs/release/artifacts/<rc-id>/` | Build artifacts + SHA-256 manifest (not screenshots) |

## Honest limitations

- Reconstructed RC references are **not** claimed as original pixel-canonical mockups.
- Full Android Deep Glass parity remains partial; iOS navigation/glass layer ported first.
