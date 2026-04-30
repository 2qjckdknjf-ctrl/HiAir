# HiAir Aurora Calm v2 — Design System

Status: canonical for cycle "aurora-calm + insights"
Owner: design + mobile
Last updated: 2026-05-01

This document is the single source of truth for visual, motion, and interaction
language of HiAir Aurora Calm v2. All new mobile UI must reference tokens from
this document. Hardcoded colors, spacings, fonts, or radii are not allowed.

## Principles

1. Calm wellness, not emergency. Background carries time-of-day mood, never risk.
2. Risk is communicated through accent surfaces, badges, glow, and ambient
   atmosphere — never by recoloring the whole screen.
3. Explainability is a feature. Reason codes ride along with every risk number.
4. Deterministic core stays the source of truth. UI never invents risk values.
5. Premium feel through restraint: one gradient CTA per screen, generous spacing,
   one hero element per surface.

## Background system (time-of-day driven)

Background is a vertical linear gradient that interpolates smoothly between the
nearest two tokens based on local time. Updates every 10 minutes.

| Token         | Hours  | Top hex   | Bottom hex |
|---------------|--------|-----------|------------|
| bg.dawn       | 5–8    | #1A1530   | #2B2050    |
| bg.morning    | 8–12   | #1B2845   | #2A4373    |
| bg.midday     | 12–16  | #1F3260   | #2E4A8A    |
| bg.afternoon  | 16–19  | #2A2547   | #3D2F5C    |
| bg.evening    | 19–22  | #1A1A35   | #25193D    |
| bg.night      | 22–5   | #0E1226   | #181D38    |

Background is never tinted by risk level. This is intentional and non-negotiable.

## Surfaces

| Token              | Construction                                     |
|--------------------|--------------------------------------------------|
| surface.primary    | bg + lightness +6%                               |
| surface.secondary  | bg + lightness +12%                              |
| surface.elevated   | bg + lightness +18% with 1px inner border 6% white |

## Text

| Token           | Hex      | Usage                                  |
|-----------------|----------|----------------------------------------|
| text.primary    | #F0F4FF  | Hero numbers, titles, primary copy     |
| text.secondary  | #A8B5D1  | Supporting copy, descriptions          |
| text.tertiary   | #6A7A99  | Timestamps, hints, captions            |

## Risk accents

Used only for badges, progress bars, glow, accent strokes. Never for backgrounds
or large surfaces.

| Token            | Hex      | Mood              |
|------------------|----------|-------------------|
| risk.low         | #7DDCB0  | Mint, calm        |
| risk.moderate    | #F5B66E  | Amber, attention  |
| risk.high        | #F08A8A  | Coral, caution    |
| risk.very_high   | #C95684  | Deep cherry, alert |

Pure red (#FF0000 family) is forbidden. It signals emergency and breaks our
wellness positioning.

## CTA gradient

Only one CTA gradient per screen. Use sparingly.

```
cta.gradient = linear-gradient(135deg, #5DD5C4 0%, #8B7BFF 100%)
```

Secondary buttons use `surface.elevated` background with `text.primary` color.

## Typography

iOS uses SF Pro family. Android uses Inter as visual fallback (similar metrics).

| Token         | Family                  | Size | Weight | Tracking |
|---------------|-------------------------|------|--------|----------|
| display.xl    | SF Pro Rounded          | 88   | 600    | -2       |
| display.lg    | SF Pro Display          | 34   | 700    | -0.5     |
| title.lg      | SF Pro Display          | 22   | 600    | 0        |
| title.md      | SF Pro Text             | 17   | 600    | 0        |
| body.lg       | SF Pro Text             | 17   | 400    | 0        |
| body.md       | SF Pro Text             | 15   | 400    | 0        |
| caption       | SF Pro Text             | 13   | 500    | 0.2      |
| mono.sm       | SF Mono                 | 13   | 500    | 0        |

`display.xl` is reserved for the hero risk number on Dashboard. Do not use it
elsewhere.

## Spacing scale

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64`

Vertical rhythm:
- Between unrelated blocks: 24
- Between related sub-elements: 12
- Inner card padding: 16 or 20

## Radius

| Token   | Value | Usage                       |
|---------|-------|-----------------------------|
| pill    | 999   | Badges, time chips, buttons |
| sm      | 8     | Inline tags                 |
| md      | 14    | Action chips                |
| lg      | 20    | Standard cards              |
| xl      | 28    | Hero cards                  |

## Motion

- Default ease: `cubic-bezier(0.32, 0.72, 0, 1)` (iOS native curve)
- Default duration: 240–320ms
- Risk number changes: animated tween (number morph) over 800ms
- Globe anchor: idle rotation 60s per full cycle
- Globe glow pulse: 4s period at low risk → 1.5s period at very_high (linear interp)

## Atmospheric layer

Ambient particles drawn behind content. Three knobs driven by environment:

| Input        | Effect                                          |
|--------------|-------------------------------------------------|
| pm25 ≤ 10    | 3 particles, opacity 0.15, size 1px            |
| pm25 11–34   | 5 particles, opacity 0.2, size 1.5px           |
| pm25 35–54   | 6 particles, opacity 0.3, size 2px             |
| pm25 ≥ 55    | 8 particles, opacity 0.4, size 3px             |

Movement uses Perlin-like noise, very slow drift (≤ 8 px/s). Never distracting.

## Globe anchor

Located in the weather card. Carries:
- Color from time-of-day base
- Glow color from current risk accent
- Glow intensity tied to overall risk score
- Slow idle rotation

The globe is a second-tier ambient risk indicator. Reading the badge is faster,
but the globe lets the user feel the day at a glance.

## Risk indicator hierarchy (three tiers)

1. Ambient — atmospheric particles density and globe glow
2. Atmospheric — risk-tinted accent surfaces (badge, progress bar, action icons)
3. Explicit — the number, the risk badge label, and the reason code line

Every dashboard surface offers all three tiers simultaneously, so the user can
glance (1), notice (2), or read (3) depending on intent.

## Haptics (iOS)

| Trigger                         | Feedback                  |
|---------------------------------|---------------------------|
| Primary CTA tap                 | UIImpactFeedbackGenerator(.light) |
| Symptom logged successfully     | UINotificationFeedbackGenerator(.success) |
| Risk crossed into high (in fg)  | UINotificationFeedbackGenerator(.warning) |
| Pull to refresh trigger         | UIImpactFeedbackGenerator(.medium) |

Android uses `HapticFeedbackConstants` equivalents where available.

## Localization

All UI strings are added to `localization.py` (backend) and `AppSession.swift`
(iOS) and `AndroidL10n.kt` (Android) with `ru` and `en` keys at the same time.
No PR is merged with one-language strings.

## Accessibility baseline

- Minimum touch target 44×44 pt
- Text contrast ≥ 4.5:1 against its surface
- Risk information must be conveyed by both color and label, never color alone
- Dynamic type support: scale down `display.xl` if user has Larger Text enabled
- VoiceOver labels include risk level and reason code, not just the number

## Forbidden patterns

- Background tint based on risk level
- More than one gradient CTA per screen
- Pure red for risk indication
- Risk number without an accompanying reason code
- Hardcoded color hex values in screen code (must reference tokens)
- New strings without ru + en pair
- Showing AI observability data, alerts orchestrator internals, or subscription
  gate diagnostics on user-facing screens

## Surface inventory for cycle Aurora Calm v2

The following screens are part of this cycle:
- Dashboard (redesign)
- Daily Planner (redesign with heat-strip)
- Symptoms Log (redesign)
- Insights (new tab)
- Settings → Notifications → Morning Briefing (new section)

Onboarding and Auth screens stay on existing styling for this cycle and are
deferred to a follow-up cycle.

## References

- Implementation tokens: `mobile/ios/HiAir/DesignSystem/Tokens.swift`
- Implementation tokens: `mobile/android/app/src/main/java/com/hiair/ui/design/Tokens.kt`
- Time-of-day background: `mobile/ios/HiAir/DesignSystem/TimeOfDayBackground.swift`
- Atmospheric layer: `mobile/ios/HiAir/DesignSystem/AtmosphericParticles.swift`
- Globe anchor: `mobile/ios/HiAir/DesignSystem/GlobeAnchor.swift`
