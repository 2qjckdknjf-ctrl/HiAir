# HiAir Design System Guardrails

Enforced by code review and `scripts/check_hiair_design_system.sh` (warning-only).

## Must

- Use design tokens for colors, spacing, radius, typography
- Use shared components (`HiAirCard`, `HiAirGradientButton`, `HiAirRiskChip`, etc.)
- Keep background time-of-day based, never risk-tinted
- Communicate risk with number + label + reason, not color alone
- Support compact / standard / tablet layouts via adaptive helpers
- Support Dynamic Type (iOS) and fontScale (Android)
- One primary gradient CTA per screen
- iOS/Android visual parity

## Must not

- Hardcode hex colors in screen/renderer files
- Use full-screen marketing PNG as app UI background
- Use pure red (#FF0000)
- Put API, Supabase, auth, or risk calculation in UI components
- Change navigation contracts or business logic during visual refit
- Stretch content edge-to-edge on tablets without max width

## Component purity

Visual components accept data via parameters only. No ViewModel ownership, no navigation, no side effects.

## Legacy debt

Pre-existing hardcoded colors in `V2Ui.kt` and opacity shortcuts are migrated incrementally. Guard script warns on new violations in screen folders.
