# Screenshot & Accessibility Matrix — 2026-08-24

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Base commit:** `ab972294` (worktree dirty — see evidence manifests for diff identity)  
**Legend:** PASS = verified locally; FAIL = defect open; BLOCKED = not locally executable

## iOS — iPhone 17 Pro Simulator

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| EN / standard / phone | PASS | `.evidence/ios-screenshots/2026-08-24-hardening-v4/` | Store suite 10/10 PNG + manifest |
| EN / standard / paywall scroll | PASS | PaywallScrollSafeAreaUITests | NavigationStack toolbar; restore hittable |
| EN / standard / tab clearance | PASS | MainTabScrollHittabilityUITests | Geometry vs `tab.bar` all 5 tabs |
| RU / standard / phone | BLOCKED | — | Capture script supports `HIAIR_SHOT_LANGUAGE=ru`; not run in this pass |
| accessibility3 / phone | BLOCKED | — | Requires Dynamic Type launch env |
| accessibility5 / phone | BLOCKED | — | Requires Dynamic Type launch env |
| Reduce Transparency | BLOCKED | — | Requires `-UIAccessibilityReduceTransparencyEnabled` |
| Reduce Motion | BLOCKED | — | Requires `-UIAccessibilityReduceMotionEnabled` |
| iPad 13" | BLOCKED | — | IPadSandboxPurchaseUITests pass on phone sim; iPad sim capture not run |
| loading / empty / error / offline | BLOCKED | — | Matrix states need dedicated UITest routes |

## Android

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| EN / phone / debug | PARTIAL | assembleDebug + lint + unit tests | Bottom nav + paywall billing fixes only |
| Deep Glass parity (8 screens) | FAIL | — | Not complete; Paywall + nav shell only |
| tablet reflow | BLOCKED | — | No fresh tablet screenshots |
| TalkBack / a11y matrix | BLOCKED | — | Manual/device automation not run |

## Release verification

| Gate | Status | Evidence |
|------|--------|----------|
| iOS Release build | PASS | `scripts/ops/verify_ios_release_leaks.sh` |
| Operator UI in Release | PASS (UI) | `#if DEBUG` guards; l10n strings WARN in binary |
| Android release bundle | PASS | `bundleRelease` unsigned dev signing |
