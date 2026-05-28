# HiAir Brand System

Status: canonical brand source of truth  
Last updated: 2026-05-27

## Brand identity

| Field | Value |
|-------|-------|
| Name | **HiAir** (never HIAir, Hi Air, HiAIR, Hi-Air, HI AIR) |
| Tagline | Breathe better. Live better. |
| Promise | Personal heat + air guidance. |
| Visual style | HiAir Orb / Aurora Calm |

HiAir is a calm wellness assistant for heat, air quality, and personal risk — not emergency medicine, not a weather map.

## Logo concept

**HiAir Orb** — glowing glass orb/globe with a soft H-shaped airflow wave inside. Cyan / teal / violet aurora glow on dark atmospheric gradients.

## Color tokens

### Background gradients (time-of-day)

| Token | Top | Bottom | Hours |
|-------|-----|--------|-------|
| bg.dawn | #1A1530 | #2B2050 | 5–8 |
| bg.morning | #1B2845 | #2A4373 | 8–12 |
| bg.midday | #1F3260 | #2E4A8A | 12–16 |
| bg.afternoon | #2A2547 | #3D2F5C | 16–19 |
| bg.evening | #1A1A35 | #25193D | 19–22 |
| bg.night | #0E1226 | #181D38 | 22–5 |

Background is **never** tinted by risk level.

### Text

| Token | Hex |
|-------|-----|
| text.primary | #F0F4FF |
| text.secondary | #A8B5D1 |
| text.tertiary | #6A7A99 |

### Risk accents (chips, badges, strokes, glow, charts only)

| Token | Hex |
|-------|-----|
| risk.low | #7DDCB0 |
| risk.moderate | #F5B66E |
| risk.high | #F08A8A |
| risk.veryHigh | #C95684 |

Pure red (#FF0000) is forbidden.

### CTA gradient

| Token | Hex |
|-------|-----|
| cta.gradient.start | #5DD5C4 |
| cta.gradient.end | #8B7BFF |

One primary gradient CTA per screen.

### Surfaces

| Token | Construction |
|-------|--------------|
| surface.primary | time-of-day bg + lightness +6% |
| surface.secondary | time-of-day bg + lightness +12% |
| surface.elevated | time-of-day bg + lightness +18% + soft border |

## Typography scale

| Token | iOS | Android |
|-------|-----|---------|
| displayXL | 88pt semibold rounded | 72sp bold |
| displayLG | 34pt bold | 30sp bold |
| titleLG | 22pt semibold | 20sp semibold |
| titleMD | 17pt semibold | 17sp semibold |
| bodyLG | 17pt regular | 17sp regular |
| bodyMD | 15pt regular | 15sp regular |
| caption | 13pt medium | 13sp medium |

## Spacing scale

4, 8, 12, 16, 20, 24, 32, 48, 64 (xxs → hero)

## Radius scale

pill 999, sm 8, md 14, lg 20, xl 28

## Shadow / glow

- CTA: cyan glow, radius ~14, opacity ~0.24
- Risk orb: risk-accent glow, subtle pulse
- Glass cards: 1px border at text.primary ~14% opacity

## Iconography

SF Symbols (iOS) / Material-style line icons (Android). Calm, rounded, not medical/emergency.

## App icon & splash

- App icon: HiAir Orb on bg.night gradient
- Splash: bg.night, centered orb, wordmark, tagline

## Screen usage rules

1. Build UI from tokens + shared components, not marketing PNGs.
2. Risk via number + label + reason code, not color alone.
3. Decorative artwork must not reduce text readability.
4. iOS and Android share the same visual system.

## Responsive / adaptive rules

| Breakpoint | iOS | Android |
|------------|-----|---------|
| compact | < 375pt | < 360dp |
| standard | 375–430pt | 360–599dp |
| large phone | 430–600pt | — |
| tablet | > 600pt | 600–839dp |
| expanded | — | ≥ 840dp |

- Max content width: 680pt / 680dp on tablet+
- Hero orb scales with available width
- ScrollView/LazyColumn for overflow
- Two-column only when width ≥ tablet threshold

## Forbidden patterns

- Full-screen marketing poster backgrounds
- Risk-colored full backgrounds
- Pure red (#FF0000)
- Hardcoded hex in screen files
- Business logic inside visual components
- Different brand language per platform

## iOS / Android parity

Same tokens, same hierarchy, same CTA gradient, same risk chip styling. Platform-native navigation patterns are allowed.
