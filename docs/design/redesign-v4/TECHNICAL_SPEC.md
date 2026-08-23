# HiAir Redesign V4 — Technical Specification

Project: HiAir  
Version: Redesign V4 / Deep Glass  
Date: 2026-08-16  
Status: approved design direction; implementation specification  
Memory id: `f4264949-8f63-4630-a07b-3ec0e322a069`

Owner intent: rebuild the presentation layer so production UI matches the approved Deep Glass renders. Preserve functional behavior and real data flows.

## Product goal

Coherent premium environmental-health product. Dark volumetric glass across Dashboard, Air Quality, Planner, Health, Symptoms, Onboarding and Settings. iOS first; Android reuses the same semantic tokens.

## Design principles

- Dark atmospheric base, not flat black.
- Volumetric layered glass, not simple opacity cards.
- Cyan / blue / violet as primary spectral identity.
- Green for good/recovery, yellow/orange for moderate/heat/UV, red/magenta for high/severe.
- Hierarchy must stay obvious; glows indicate depth/state.
- Slow ambient motion; fast precise controls.
- No default SwiftUI appearance on production surfaces where it breaks the language.

## Visual tokens

| Token | Hex |
|---|---|
| bg0 | `#050B16` |
| bg1 | `#081221` |
| bg2 | `#0B1730` |
| bg3 | `#101B37` |
| text primary | `#F4F7FF` |
| text secondary | `#A9B6D3` |
| text tertiary | `#6F7F9D` |
| cyan | `#21D7FF` |
| electric blue | `#3D7BFF` |
| violet | `#8C5CFF` |
| magenta | `#D05CFF` |
| good | `#35E6A2` |
| moderate | `#FFD447` |
| heat | `#FF8A3D` |
| severe | `#FF4D68` |

CTA gradient: cyan → electric blue → violet.

Spacing base grid: 4 pt. Side padding 16–20. Card gaps 10–14. Section gaps 20–28.

Radii: chip 12–14, compact 16, card 20, hero 24, tab bar 28–32, CTA 18–22.

## Deep Glass material

Reusable `HiAirGlassSurface` / `hiAirGlassSurface`:

- translucent navy fill
- refractive inner gradient
- top/leading specular highlight
- 1 px spectral border + inner border
- outer ambient shadow + localized semantic glow
- pressed depth
- Reduce Transparency fallback (opaque fill, stronger border)

Hero/active cards are brightest; passive cards stay restrained.

## Atmospheric background

`HiAirAtmosphericBackground`: layered navy gradients, cyan glow top-leading, violet glow opposite, 12–20 s drift, Reduce Motion static.

## Motion

| Event | Timing |
|---|---|
| button press | 100–160 ms, scale 0.97–0.985 |
| chip | 160–240 ms |
| tab | 220–320 ms |
| card entrance | 250–350 ms |
| orb breath | 4–6 s |
| background drift | 12–20 s |

## Components

Tokens in `DesignSystem/`. Surfaces: glass card, atmospheric background, primary/secondary buttons, chips, risk orb/gauge, floating tab bar, skeleton/empty/error.

## Screen targets

Dashboard, Air Quality, Planner, Health, Symptom Tracker, Onboarding, Settings — see Memory OS spec body for per-screen required hierarchy.

Tab chrome is restyled as a floating glass bar. Product still exposes the existing five destinations; do not drop Insights or Symptoms.

## Migration rules

- Separate branch.
- Incremental presentation replacement.
- Do not remove working API integrations to match a mockup.
- Mock values never leak into production runtime.

## Locked decision

Deeper volumetric glass iteration is the baseline until a later user-approved Memory OS record supersedes it.
