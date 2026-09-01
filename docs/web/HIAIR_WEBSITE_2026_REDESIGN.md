# HiAir Website 2026 Redesign

Date: 2026-08-31

Branch: `feat/hiair-premium-website-2026`

Production baseline: `23eeea664d210dc7f539f2a301dc54042d64e02f`

## Outcome

The homepage is now a product-first consumer experience built on the existing static stack. The first screen states the core job, shows a real captured iOS dashboard, and presents the verified App Store action. Four large product stories replace the repeated feature-card catalogue. No framework, animation library, analytics provider, API dependency, or new deployment mechanism was added.

## Product and content decisions

- Primary promise: “Know the best time to go outside.”
- The site uses “more suitable” rather than guaranteed-safe language.
- Real screenshots come from `docs/brand/store-assets/asc-screenshots/captured-iphone/`; optimized web copies live under `web/assets/product/`.
- The interactive experience is deterministic sample data and is labeled `Demo example`; it sends no location, activity, health, or result values to analytics.
- Pollen and smoke are described only as coverage-dependent.
- Apple Health is optional and described as activity-summary context, not medical interpretation.
- Family is described conservatively as linked profiles. Travel is described as saved-place planning.
- Premium benefits reflect the in-repository paywall; pricing remains “See pricing in the app.”
- Android is explicitly not publicly listed and no Google Play badge or URL is rendered.
- Notifications are omitted because implementation evidence marks push as not wired.

## Visual system

`web/premium-2026.css` extends the existing HiAir tokens instead of replacing the shared design system. The page uses restrained cyan/blue/violet accents, alternating dark and light editorial sections, generous spacing, strong type scale, real product frames, and limited glass. Motion is restricted to small hover transitions and respects `prefers-reduced-motion`.

Responsive breakpoints cover compact desktop/tablet (`980px`), phone (`720px`), and narrow phone (`390px`). Mobile gets a compact menu, stacked product stories, touch-sized controls, safe-area bottom spacing, and one persistent App Store action.

## Product-design review passes

1. Product pass: replaced the synthetic hero, condensed the promise, reduced the repeated-card pattern, introduced four differentiated stories, and made one App Store action dominant.
2. Trust and mobile pass: added example labels, data-availability qualifiers, optional-context boundaries, touch targets, stacked phone layouts, and safe-area handling.
3. Rhythm and performance pass: tightened section hierarchy and CTA consistency, kept motion to explanatory microinteractions, added fixed media dimensions/lazy loading, and replaced the 889 KB source app icon in the final CTA with a 4.4 KB optimized derivative.

## Interactive demo

The homepage demo supports Barcelona, Madrid, and London with Walk, Run, and Outdoor time. Results are deterministic examples stored in `web/js/main.js`; no HiAir or third-party endpoint is called. This avoids private API, privacy, availability, and deployment risk while still demonstrating the planner interaction.

## Analytics events

All events use the existing Growth OS transport. Only page, placement, locale, campaign, UTM parameters, and anonymous/session identifiers are sent.

| Event | Trigger |
| --- | --- |
| `hero_app_store_click` | Hero App Store badge |
| `header_download_click` | Header Download action |
| `demo_started` | First demo focus/change |
| `demo_completed` | Demo result submission |
| `premium_viewed` | Premium section reaches the observer threshold |
| `faq_opened` | FAQ answer expands |
| `final_cta_click` | Final App Store badge |
| `ios_download_click` | Any App Store CTA |
| `android_download_click` | Guarded support for a future verified Play CTA; none is rendered today |

Legacy `app_store_cta.viewed` and `app_store_cta.clicked` remain intact for continuity.

## Files and ownership

- Homepage structure and schema: `web/index.html`
- Homepage presentation: `web/premium-2026.css`
- Demo and analytics: `web/js/main.js`
- Analytics coverage: `web/js/growth-telemetry.test.cjs`
- Real web product media: `web/assets/product/`
- Science & Data source/generator: `scripts/ops/generate_web_seo_content.py`
- Generated content and sitemap: `web/*/index.html`, `web/guides/**`, `web/methodology/index.html`, `web/sitemap.xml`

## Known verification gap

The local static preview server was started successfully, but the managed cloud browser could not reach repository localhost. No Chromium binary is installed in the shell runtime, so Lighthouse and breakpoint screenshots could not be produced without introducing an unapproved browser install. CI, a hosted preview, Lighthouse scores, and physical-device review remain release gates.
