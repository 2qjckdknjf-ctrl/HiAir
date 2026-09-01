# HiAir Website Release Checklist

Date: 2026-08-31

## Product truth

- [x] Public iOS listing and app id verified.
- [x] Official App Store badge and canonical listing used.
- [x] Android marked not public; no Play CTA rendered.
- [x] Pollen/smoke availability qualified.
- [x] Notifications omitted.
- [x] Premium benefits traced to implementation; no regional price hardcoded.
- [x] No ratings, reviews, user counts, featured logos, or medical/safety guarantees.

## Website and SEO

- [x] Real product screenshot appears in the hero.
- [x] Demo values are labeled examples and use no live/private API.
- [x] Canonical, Open Graph, Twitter, schema, sitemap, and robots retained.
- [x] `python3 scripts/ops/check_web_seo.py` passes.
- [x] `python3 scripts/ops/check_web_local_routes.py` passes.
- [x] SEO generator is idempotent after commit.
- [x] Public App Store, legal, support, sitemap, robots, and reference URLs return HTTP 200.

## Analytics and privacy

- [x] Existing Growth OS retained; no second platform added.
- [x] Required conversion events implemented and tested.
- [x] Demo telemetry excludes city, activity, environmental result, health, location, and email.
- [x] Public privacy statements match `/privacy/` and avoid on-device-only claims.

## Accessibility and responsive design

- [x] Semantic landmarks, one H1, labels, FAQ states, and keyboard menu behavior retained.
- [x] Visible focus styles and touch-sized controls added.
- [x] Explicit image dimensions and alt text added.
- [x] Reduced-motion behavior retained.
- [x] CSS includes tablet, phone, narrow-phone, and safe-area handling.
- [ ] Hosted visual review at phone, tablet, and desktop widths.
- [ ] Automated browser accessibility audit.

## Performance and deployment

- [x] No framework, animation library, or new third-party script added.
- [x] Product WebP media totals under 120 KB; non-hero media is lazy-loaded.
- [x] Exact web CI command set passes locally.
- [ ] Lighthouse run against a production-like hosted preview.
- [ ] Pull-request CI green.
- [ ] Cloudflare preview verified.
- [ ] Production deploy verified after merge approval.

## Git/review

- [x] Dedicated feature branch used; no direct main changes.
- [x] Audit committed before implementation.
- [x] No secrets, temporary captures, or debug output included.
- [ ] PR approval and required checks complete.
- [ ] Final merge performed by an authorized reviewer.
