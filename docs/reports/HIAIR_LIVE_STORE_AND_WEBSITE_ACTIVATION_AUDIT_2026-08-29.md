# HiAir live store and website activation audit

**Date:** 2026-08-29  
**Auditor:** autonomous agent cycle (live storefront first, then website, then production)

# Executive verdict

```text
PARTIAL
```

iOS is a real public App Store product. Google Play is not a public listing. `hiair.io` was converted from waitlist/pre-launch copy to a live iOS download site, deployed to production, and verified against the public HiAir storefront. Android is not advertised as downloadable.

COMPLETE is withheld because Android is not publicly listed and this environment could not complete an interactive click on the apex hostname `hiair.io` (TCP timeout / Chrome error). The same production HTML was verified on the Cloudflare Pages deployment URL and via WebFetch of `https://hiair.io/`.

# Repository

```text
base SHA:     9264d105c6b95ac2d5fff154206ab32dd9a8568d  (origin/main at start)
final SHA:    90a3861293c545b515fe9acf9bdd16251f8d88ab  (merge of PR #63 on main)
feature SHA:  da51aad8635557ed02f1c393fa3d4f53de71855e
branch:       feat/web-live-product-store-activation → main
worktree:     /Users/alex/Projects/HIAir-wt-live-store-site
dirty origin: /Users/alex/Projects/HIAir left untouched on design/redesign-v4-deep-glass
```

# Store status

| Platform | Identity | Public status | Canonical URL | Verification |
|---|---|---|---|---|
| iOS | HiAir / `com.hiair.app` / id `6773610034` / seller Aleksandr Potkin / version 1.1 | `PUBLIC_CONFIRMED` | `https://apps.apple.com/us/app/hiair/id6773610034` | iTunes Lookup `resultCount=1`; public storefront US/ES; HTTP 200 on production CTA URL |
| Android | package `com.hiair` (from `mobile/android/app/build.gradle.kts`) | `NOT_PUBLIC` | none | `https://play.google.com/store/apps/details?id=com.hiair` HTTP 404; Exa `CRAWL_NOT_FOUND` |

Machine-readable source of truth: `web/config/store-links.json` (generated into `web/js/store-links.js`).

# Website updates

Changed pages/components:

- `web/config/store-links.json` — canonical store truth
- `web/js/store-links.js` — generated runtime helper
- `web/index.html` — hero App Store badge, download block, Android notify form, FAQ, footer
- `web/js/main.js` — hydrate verified CTAs; hide Play CTAs unless public
- `web/styles.css` — download panel + official badge layout
- `web/assets/badges/download-on-the-app-store.svg` — official Apple badge
- Generated content hub pages via `scripts/ops/generate_web_seo_content.py` (about, contact, guides, audience pages)
- `web/404.html`, `web/sitemap.xml`, `web/APP_STORE_UTM.md`
- SEO/route gates: `scripts/ops/check_web_seo.py`, `scripts/ops/check_web_local_routes.py`
- CI: `.github/workflows/hiair-io-pages.yml`

# Removed stale claims

Production-facing phrases found on `origin/main` / live site and replacements:

| Old (public) | New |
|---|---|
| Meta: “Join early access for iOS and Android.” | “Download HiAir on the App Store.” |
| JSON-LD `operatingSystem`: “iOS, Android” | `operatingSystem`: “iOS” only |
| Hero: “iOS is on the App Store. Android waitlist below.” | “Available on the App Store. Android is not publicly listed yet.” |
| Waitlist CTA: “Join early access” | “Notify me about Android” |
| FAQ: “When will early access be available?” | “Where can I download HiAir?” |
| Contact meta: “early-access information” | product support / App Store download help |
| About: “HiAir is preparing wider availability for iOS and Android” | “HiAir is on the App Store… An Android listing is not public yet.” |

JSON-LD does not invent ratings, review counts, or a fake free `offers.price`.

# Link verification

| Source | CTA | Destination | Result |
|---|---|---|---|
| Production HTML (Pages deploy `ec96a863`) header/hero/final/faq/footer | Download on the App Store / App Store | `https://apps.apple.com/us/app/hiair/id6773610034?utm_…` | PASS — HTTPS, canonical id `6773610034` |
| Hero CTA HTTP follow | App Store badge | final `https://apps.apple.com/us/app/hiair/id6773610034?ct=app_store_cta_hero` | PASS — HTTP 200 |
| Chrome click from production Pages HTML header CTA | Download on the App Store | `https://apps.apple.com/us/app/hiair/id6773610034` titled “HiAir App - App Store” | PASS |
| Google Play details | none on site | `https://play.google.com/store/apps/details?id=com.hiair` | NOT advertised; public listing HTTP 404 |

No `href="#"`, `javascript:void(0)`, or Play details URLs on public HTML.

# Tests

```text
lint:            N/A (static HTML/CSS/JS); python3 -m py_compile on web ops scripts PASS
typecheck:       N/A (no TypeScript website)
tests:           node --test web/js/store-links.test.cjs web/js/growth-telemetry.test.cjs  → 8/8 pass
build:           python3 scripts/ops/generate_web_seo_content.py drift-free; check_web_seo PASS (13 URLs); check_web_local_routes PASS (22 routes + 404)
E2E:             no website Playwright suite; browser-use click-through on production Pages artifact + HTTP follow
CI validate:     GitHub Actions hiair-io-pages run 33263349858 validate SUCCESS
```

# Production verification

```text
deployment ID:   GitHub Actions run 33263349858
commit SHA:      90a3861293c545b515fe9acf9bdd16251f8d88ab
Pages URL:       https://ec96a863.hiair-web.pages.dev
timestamp:       2026-08-29T16:35:26Z
status:          validate SUCCESS + deploy SUCCESS (Pages + Worker proxy)
hiair.io HTTP:   WebFetch of https://hiair.io/ after deploy shows the new live-product copy
desktop:         evidence/2026-08-29-desktop-homepage.png
mobile:          evidence/2026-08-29-mobile-homepage.png
download block:  evidence/2026-08-29-desktop-download.png
App Store click: header CTA from production HTML → apps.apple.com/us/app/hiair/id6773610034
Google Play:     not advertised
```

Local `curl` to `https://hiair.io/` from this agent host timed out; Cloudflare Pages origin and WebFetch succeeded. Treat that as an agent-network limitation, not as a proof that the apex is down.

# Remaining blockers

1. **Google Play is not a public listing**  
   - **Source:** HTTP 404 on `https://play.google.com/store/apps/details?id=com.hiair` (2026-08-29). Console/internal testing is not a public storefront.  
   - **Impact:** Website correctly does not show a Play badge or “Download on Google Play”.  
   - **Exact next action:** Owner publishes a production Play Store listing for `com.hiair`, then set `web/config/store-links.json` `android.status` to `PUBLIC_CONFIRMED` with the verified URL and regenerate.

2. **Agent host cannot reliably TCP-connect to apex `hiair.io`**  
   - **Source:** `curl --max-time 12 https://hiair.io/` → timeout; Cursor IDE browser `chrome-error://chromewebdata/`. WebFetch and Pages origin work.  
   - **Impact:** Interactive click-through was executed on the identical production Pages artifact, not on the apex hostname in this Chrome profile.  
   - **Exact next action:** Optional: from a normal consumer network, click header “Download on the App Store” on `https://hiair.io` and confirm the US/ES HiAir listing.

# Store identity verification

## iOS

```text
Store URL:              https://apps.apple.com/us/app/hiair/id6773610034
App name:               HiAir
App ID:                 6773610034
Developer / seller:     Aleksandr Potkin
Bundle ID:              com.hiair.app
Version:                1.1
Release / update:       first public 2026-08-25; current version 2026-08-26T05:00:59Z
Public availability:    PUBLIC_CONFIRMED (US default + ES storefront)
Verification method:    iTunes Lookup API + public storefront fetch + HTTP 200 on website CTA + Chrome tab after header click
```

## Android

```text
Store URL:              none (not public)
App name:               HiAir (intended)
Package ID:             com.hiair
Developer:              not observable on a public listing
Version/update:         not observable on a public listing
Public availability:    NOT_PUBLIC
Verification method:    Gradle applicationId + Play details HTTP 404 + Exa CRAWL_NOT_FOUND
```
