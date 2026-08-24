# Store-Ready Hardening Status — 2026-08-24

**Verdict:** `NO-GO / HARDENING IN PROGRESS`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**RC source SHA (clean):** `ef82878755910c1e03cf7ccf3a9106df840c7e3c`

## Closed in this pass

- iOS Deep Glass V4 main tabs + floating tab bar fade/clearance
- Planner independent forecast/activity state machine
- Paywall NavigationStack chrome, ASC length identifiers, scroll regression test
- Settings operator copy removed (EN/RU); DEBUG-only operator UI
- Screenshot pipeline: exact 10 PNG names, empty-dir guard, provenance manifest, contract test
- Release build verification script (DEBUG UI stripped; operator l10n WARN in binary)
- Full iOS unit (213) + UI (20) regression green
- Android paywall billing gates, legal URL config, bottom nav, subtitle fix
- Reference PNGs + visual comparison register

## Open / BLOCKED

- **Android Phase 4 parity** — 8 screens + nav shell Deep Glass incomplete
- **Full iOS/Android a11y matrix** — RU, a11y3/5, Reduce Motion/Transparency, iPad captures
- **Operator l10n in Release binary** — UI unreachable; optional DEBUG-only string table split
- **ASC/Play signed upload artifacts** — local builds use development signing only
- **Physical device / Sandbox IAP certification** — external owner verification
- **Truth-alignment operator runbooks** — partial; RC manifest in repo pending final commit

## Owner actions

1. Review `.evidence/ios-screenshots/2026-08-24-hardening-v4-final/` captures
2. Complete Android screen parity sprint
3. Run locale/a11y/iPad matrix captures
4. ASC Sandbox purchase on physical device / TestFlight when ready
5. Explicit «можно сабмитить» before submit/publish
