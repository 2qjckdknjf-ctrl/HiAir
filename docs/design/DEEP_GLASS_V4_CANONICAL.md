# Deep Glass V4 — Canonical Design Direction (RC worktree)

**Status:** Phases 1–4 integrated on branch `cursor/store-ready-hardening-2026-08-22` (Dashboard, Planner, Health/Symptoms, Onboarding); screenshot matrix + Android screen parity in progress  
**Visual direction:** Deep Glass V4  
**UX/accessibility foundation:** Aurora Calm v2  
**Source reference (read-only):** `/Users/alex/Projects/HIAir` @ `design/redesign-v4-deep-glass`  
**Inventory:** [Deep Glass V4 inventory](8c66d09b-2e97-41de-be5b-fe5c1ea16fd8) (main vs store-ready diff, 2026-08-22)

## Port status (selective)

| Phase | Scope | RC status |
|-------|--------|-----------|
| 1 | Tokens + contrast (iOS + Android colors, gradients, radii, motion) | **Done** |
| 2 | Glass stack (`HiAirGlassSurface`, slim `HiAirLiquidGlass`) | **Done** |
| 3 | Floating tab bar + `RootTabView` | **Done** |
| 4 | `HiAirDeepGlassWidgets`, `HiAirDeepGlassLayout`, `HiAirAtmosphericBackground`, per-screen layout | **Ported** (iOS Dashboard, Planner, SymptomLog/Health, Onboarding) |
| 5 | `docs/design/redesign-v4/` spec + references | **Spec only** (`README.md`, `TECHNICAL_SPEC.md`; PNG refs remain on main) |

Do **not** blind-merge `design/redesign-v4-deep-glass`. Port Phase 4 screen-by-screen with regression tests.

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
