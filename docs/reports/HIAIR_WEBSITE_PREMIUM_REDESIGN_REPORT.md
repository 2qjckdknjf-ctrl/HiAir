# HiAir Website Premium Redesign Report

Date: 2026-08-31

Verdict: `PARTIAL`

Branch: `feat/hiair-premium-website-2026`

Production baseline: `main@23eeea664d210dc7f539f2a301dc54042d64e02f`

## What changed and why

The homepage was rebuilt as a premium, product-first static experience. It now explains HiAir in the first heading, shows real iOS UI immediately, demonstrates the difference between environmental numbers and an actionable recommendation, offers a deterministic example planner, tells four large product stories, and explains Apple Health, Premium, science, privacy, and availability without unsupported claims. Existing SEO generation, Growth OS telemetry, legal routes, store-link truth, and Cloudflare deployment are preserved.

## Files changed

- `web/index.html`, `web/premium-2026.css`
- `web/js/main.js`, `web/js/growth-telemetry.test.cjs`
- `web/assets/product/app-icon.webp`
- `web/assets/product/ios-dashboard.webp`
- `web/assets/product/ios-symptoms.webp`
- `scripts/ops/generate_web_seo_content.py`
- Generated pages under `web/about/`, `web/contact/`, `web/for-*`, `web/air-quality-sensitive/`, `web/guides/`, `web/methodology/`
- `web/sitemap.xml`
- Documentation under `docs/web/` and this report

## Features shown

Production: live/recently cached air quality, heat, personalized wellness risk, planner/best available outdoor window, walking, running, outdoor-time guidance, location personalization, Premium. Limited and qualified: pollen, smoke, Apple Health, linked family profiles, saved-place planning. Excluded: notifications, public Android download, unverified ratings/reviews/counts, fixed regional prices, medical or guaranteed-safe claims.

## Store validation

The canonical App Store URL `https://apps.apple.com/us/app/hiair/id6773610034` returned HTTP 200 and matches `web/config/store-links.json` (`PUBLIC_CONFIRMED`, version evidence 1.1). The homepage uses Apple's official badge. Android remains `NOT_PUBLIC`; no Play link or badge is present.

## Analytics

The existing Growth OS transport now records `hero_app_store_click`, `header_download_click`, `demo_started`, `demo_completed`, `premium_viewed`, `faq_opened`, `final_cta_click`, `ios_download_click`, and guarded future `android_download_click`. Legacy App Store view/click events remain. New event properties contain no health, city, activity, result, precise location, or email value.

## SEO

Homepage title/description and matching social metadata now center on best-time outdoor planning. Homepage JSON-LD uses truthful `SoftwareApplication`, `Organization`, `WebSite`, and visible `FAQPage` content. Science & Data improves the existing `/methodology/` route rather than creating a duplicate. Sitemap remains at 13 original-content URLs. SEO and route checks pass.

## Accessibility

Implemented: skip link, semantic sections, one H1, labels, native buttons/selects, FAQ `aria-expanded`, menu Escape handling, visible focus rings, alt text, explicit media dimensions, 46–54px controls, reduced motion, and safe-area mobile CTA. Browser automation accessibility scoring remains unverified because the managed cloud browser could not reach local preview and the shell has no Chromium binary.

## Performance

The change adds no runtime dependency and no hydration. The two real screenshots total 110,698 bytes; the optimized app icon is 4,382 bytes; total homepage HTML/CSS/JS plus product media and store badge/QR is approximately 230 KB before transfer compression, excluding shared brand assets and the externally hosted Inter font. Hero media is 68,036 bytes with fixed dimensions; below-fold product media is lazy-loaded. Lighthouse/Core Web Vitals were not measured, so target attainment is not claimed.

## Tests and evidence

Passed locally:

- `python3 scripts/ops/generate_web_seo_content.py && git diff --exit-code -- web`
- `python3 scripts/ops/check_web_seo.py` → 13 sitemap URLs, 13 unique titles
- `python3 scripts/ops/check_web_local_routes.py` → 23 routes + 404
- workflow Python compilation and all seven JavaScript syntax checks
- `node --test web/js/store-links.test.cjs web/js/growth-telemetry.test.cjs web/js/growth-experiment.test.cjs web/js/growth-experiment-browser.test.cjs` → 28 passed, 0 failed
- Public link HTTP checks → App Store, homepage, privacy, terms, contact, sitemap, robots, and four cited science references returned 200

No pre-existing or introduced failure was observed in the web validation set. Application/backend test suites were not rerun because no application/backend code changed.

## Deployment status and known gaps

Production was not changed. The workflow deploys only from `main` after validation. A local static server ran on port 4173, but the cloud browser could not access repository localhost; no hosted preview was produced because Cloudflare credentials are not available in the workspace and the PR workflow does not deploy previews. Required CI, hosted visual review, automated accessibility, Lighthouse, and production verification remain open.

## Final verification matrix

| Control | Before | After | Evidence | Status |
| --- | --- | --- | --- | --- |
| Product/site alignment | Broad claims and synthetic hero | Evidence-bounded product story | Audit matrix + homepage copy | PASS |
| App Store availability | Public | Public | Manifest + HTTP 200 + official listing | PASS |
| App Store link | Verified link present | Verified link primary and repeated | Store-link tests | PASS |
| Android status | Waitlist competed with CTA | Truthful non-public status, no Play CTA | Manifest + tests | PASS |
| Hero | Abstract promise + CSS mock | Core promise + real iOS dashboard | `web/index.html` | PASS |
| Real product screenshots | Not prominent | Dashboard and symptom journal | Source assets + WebP copies | PASS |
| Interactive demo | None | Deterministic, labeled example | `web/js/main.js` | PASS |
| Planner | Described | Dedicated timing story + demo | Homepage | PASS |
| Environmental factors | Broad cards | Qualified decomposition | Homepage + Science & Data | PASS |
| Personalization | Broad wearables copy | Profile/activity/optional context | Homepage | PASS |
| Apple Health | Broad wearable claim | Dedicated optional-context section | Implementation audit | PASS |
| Family | Broad feature card | Conservative linked-profile note | Audit matrix | PASS |
| Travel | Broad feature card | Saved-place planning only | Audit matrix | PASS |
| Premium | No comparison | Truthful Free/Premium, in-app pricing | Paywall evidence | PASS |
| Science/Data | Methodology page | Expanded/renamed journey | `/methodology/` | PASS |
| Privacy | Policy linked | Specific summary + unchanged policy | `/privacy/` | PASS |
| SEO | Strong existing base | Preserved and improved homepage | SEO checker | PASS |
| Structured data | Valid but broader old copy | Matching SoftwareApplication/FAQ | SEO checker | PASS |
| Sitemap | 13 URLs | 13 URLs, refreshed lastmod | Generator + checker | PASS |
| Robots | Valid | Preserved | HTTP 200 + route check | PASS |
| Analytics | Legacy store CTA events | Required conversion set added | 28 tests | PASS |
| Mobile | Responsive old layout | Dedicated breakpoints/sticky CTA | CSS review only | PARTIAL |
| Accessibility | Good semantic base | Focus, labels, media, motion improved | Static/code review | PARTIAL |
| Performance | No baseline Lighthouse | ~230 KB critical page set; no score | Byte measurement | PARTIAL |
| Broken links | No known public breakage | Checked public/internal links | Route + HTTP checks | PASS |
| CI | Baseline green history | Local CI equivalent passes | Commands above | PARTIAL — remote pending |
| Preview deployment | None | Local server only | Port 4173; no hosted URL | PARTIAL |
| Production deployment | Baseline on main | Intentionally unchanged | Workflow policy | PASS |
| Open P0 | None known | None known | Audit/test results | PASS |
| Open P1 | Visual/perf proof missing | Hosted preview, a11y, Lighthouse, CI | Release checklist | OPEN |

## Final verdict

`PARTIAL`

The implementation and local web checks are complete, but the user's `READY_TO_MERGE` gate explicitly requires green remote CI, verified hosted preview/mobile review, accessibility evidence, and actual Lighthouse measurements. Those items cannot truthfully be claimed in the current environment.
