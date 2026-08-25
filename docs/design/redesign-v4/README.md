# HiAir Redesign V4 / Deep Glass

Canonical visual direction approved 2026-08-16 (Sasha Memory OS).

- Technical spec: `f4264949-8f63-4630-a07b-3ec0e322a069`
- Render manifest: `59a98cc9-2f08-4658-a277-57405528a953`

This folder is the in-repo drop for Cursor/agents. Original ChatGPT Library PNG bytes were not reachable from this workspace; `references/` currently holds **working reconstructions** generated from the spec so implementation can proceed. Replace them with the library originals when GitHub/ChatGPT write access is available and verify SHA-256 against `manifest.json` → `chatgpt_library`.

## Files

| Path | Role |
|---|---|
| `TECHNICAL_SPEC.md` | Implementation specification |
| `manifest.json` | Render identities, hashes, library ids |
| `references/01-home-deep-glass.png` | Home / Dashboard target |
| `references/02-planner-deep-glass.png` | Planner target |
| `references/03-health-deep-glass.png` | Health / Check-in target |
| `references/04-onboarding-deep-glass.png` | Onboarding target |
| `references/05-screen-system-overview.png` | Secondary storyboard |

Individual Deep Glass screens (1–4) take precedence over the storyboard.

## Implementation notes

- Presentation only: tokens, glass, background, buttons, tab bar chrome. Do not change API, auth, or data flows.
- Keep the existing five tabs (Home, Plan, Insights, Symptoms, Settings). Spec 4-tab IA is not applied.
- iOS is the first implementation surface; Android reuses the same semantic tokens.
