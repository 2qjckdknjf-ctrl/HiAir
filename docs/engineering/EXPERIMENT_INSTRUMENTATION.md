# HiAir experiment runtime (local / flag off)

Not deployed. `HIAIR_EXPERIMENTS_ENABLED` is hardcoded `false` in `web/js/main.js`. Production HTML does not load the experiment modules (`store-links.js` + `main.js` only).

## Control fallback

Any of: flag off, empty config, network failure, bad payload, missing CONTROL, bad variant, assignment failure, crypto unavailable, storage unavailable, storage write failure, invalid treatment config → **CONTROL**. Existing CTA copy stays `Download on the App Store`. No config request when the flag is false.

## Assignment

- Unit: **VISITOR** (`hiair_growth_anon`)
- Hash: **async** `globalThis.crypto.subtle.digest("SHA-256", UTF-8 bytes)` of `experiment_id + ":" + assignment_version + ":" + anonymous_id`
- Not CommonJS `require("crypto")`. Crypto failure does **not** collapse to bucket 0; it returns CONTROL.
- Sticky key: `growth_experiment:<experiment_id>:<assignment_version>` in `localStorage`
- Stored value must match experiment/version and a live allocation variant. Unknown variants are ignored.
- Treatment requires a successful sticky write. `localStorage` missing or `setItem` failure → CONTROL.
- New `session_id` must not re-randomize
- Allocation change for a running design requires a new `assignment_version`. v1 sticky must not leak into v2.

## Exposure

`experiment.exposed` after IntersectionObserver ≥50% visible for ≥1000 ms. Not `app_store_cta.viewed`. Event id is deterministic; retry until transport succeeds.

## Telemetry

v2 fields: `experiment_id`, `variant_id`, `assignment_version`, `placement`, plus existing `anonymous_id` / `session_id`. Clicks reuse `app_store_cta.clicked` with those fields only when an experiment is active.

## Mutations

Allowlisted `cta_copy` via `textContent` only. No `eval`, script URLs, or HTML injection.

## Rollback

Set `HIAIR_EXPERIMENTS_ENABLED=false` (already the default) and omit experiment script tags. Existing CTA telemetry remains event_version 1.
