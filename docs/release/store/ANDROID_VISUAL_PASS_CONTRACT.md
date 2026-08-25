# Android Store Visual PASS Contract (2026-08-24, updated 2026-08-25)

**Current evidence:** `dev-20260825-v4-visual-4c` — semantic **12/12 PASS**, shelf **12/12 PASS**, visual **12/12 PASS** (manual review in `visual-review.json`, synced into `manifest.json`).

Verdict ladder for **new** captures: **NO-GO / HARDENING IN PROGRESS** until manual visual review passes. A completed run with `visual_gate: 12/12 PASS` may advance local readiness to **CODE-READY / EXTERNAL ACTIONS REQUIRED** (not STORE-READY).

## Evidence artifacts

- `{shot_id}.raw.png` — full emulator screencap (may include launcher shelf)
- `{shot_id}.app.png` — cropped app viewport; **only** file used for visual review
- `{shot_id}.capture_meta.json` — dimensions, crop bounds, shelf detection, SHA-256 per file
- `visual-review.json` — manual visual gate (12 primary shots); **authoritative** for visual PASS/FAIL
- `manifest.json` — semantic capture record; `visual_review` fields synced from `visual-review.json` via `sync_android_visual_manifest.py`

Capture **FAIL** if post-crop shelf scan detects launcher shelf rows (≥8px bright band or icon-colored rows) in `*.app.png`.

Bounds resolution order: geometry markers (`geometry.navigation.bar` bottom, top fixed at 0) merged with `dumpsys window` frame for `com.hiair`, then iterative bottom-row trim via RGBA crop (not `sips` bottom crop).

## Two fidelity modes (no literal iPhone↔Android tablet pixel-match)

### Phone fidelity

Dashboard, Planner, Symptoms, Onboarding (phone / narrow):

- Same V4 hierarchy and primary components
- Close proportions, glass, light, icons, typography, spacing
- Platform chrome may differ

### Tablet responsive fidelity

Tablet / landscape / expanded:

- Bounded canvas; 2- or 3-column composition where appropriate
- No random empty voids; unified alignment axis
- Proportional cards; full useful viewport
- V4 hierarchy and component language preserved

### Component-system fidelity (no canonical PNG)

Settings and Paywall: judge against Deep Glass V4 component system, not a missing pixel reference.

## Visual PASS allowed when

- Content complete; no overlap/crop defects
- No launcher shelf in `*.app.png`
- No emoji/text placeholder icons
- Phone screens follow V4 hierarchy faithfully
- Tablet uses logical responsive composition
- Glass components consistent (`HiAirV4Glass` contract)
- No large accidental empty areas
- Navigation does not obscure scrollable controls
- Contrast and typography readable

## Semantic vs visual

- **Semantic 12/12** — automated markers, business rules, no raw keys
- **Visual PASS** — manual review per mode above; never inferred from semantic PASS alone
- **End-scroll shots** (`*-end-scroll`) — supplemental evidence; `visual_review: SUPPLEMENTAL` in manifest
