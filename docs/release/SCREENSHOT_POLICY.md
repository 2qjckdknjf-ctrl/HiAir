# Screenshot storage policy

| Location | Purpose | Git |
|---|---|---|
| `docs/brand/store-assets/asc-screenshots/current/` | App Store Connect upload set (curated, device-class sized) | tracked when finalized |
| `docs/brand/store-assets/asc-screenshots/captured-*/` | Simulator capture output pending visual QA | gitignored / evidence |
| `docs/release/qa-evidence/<date>/` | RC regression matrix (a11y scales, states, before/after) | tracked per RC |
| `mobile/ios/build/screenshots/` | Ephemeral UITest output | never commit |

Workflow: capture → open every PNG → fix defects → rebuild → re-capture → promote only approved shots to `current/`.
