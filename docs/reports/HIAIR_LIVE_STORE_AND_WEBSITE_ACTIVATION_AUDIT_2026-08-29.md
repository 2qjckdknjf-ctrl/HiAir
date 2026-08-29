# HiAir live store and website activation audit

**Date:** 2026-08-29  
**Auditor:** autonomous agent cycle (live storefront first, then website, then production)

# Executive verdict

```text
PARTIAL
```

iOS is a real public App Store product (HiAir, id `6773610034`, seller Aleksandr Potkin). Google Play has **no public listing** for `com.hiair` (HTTP 404 / «Страница не найдена»). `hiair.io` was converted from waitlist/pre-launch copy to a live iOS download site, shipped to Cloudflare Pages, and verified against the public HiAir storefront. Android is not advertised as downloadable.

`COMPLETE` is withheld for two honest reasons:

1. Android is not publicly listed, so the consumer product is iOS-only (by design of this cycle, not a website defect).
2. This agent host cannot TCP-connect to apex `https://hiair.io` (curl timeout; Cursor Chrome `chrome-error://`). The same production HTML was verified on `https://hiair-web.pages.dev/` and via Exa fetch of `https://hiair.io/`.

# Repository

```text
worktree:              /Users/alex/Projects/HIAir-wt-live-store-site
dirty origin tree:     /Users/alex/Projects/HIAir left untouched (design/redesign-v4-deep-glass)
base SHA (start):      9264d105c6b95ac2d5fff154206ab32dd9a8568d  (origin/main at cycle start)
live-product merge:    90a3861293c545b515fe9acf9bdd16251f8d88ab  (PR #63)
QR / CTA follow-up:    f48b1044a44a1bae0515b96eaf043ed4a706a8a0  (PR #65, Pages deploy SHA)
audit commit:          56ec9b616819e0c5d7b5b289310753f45c834ecd
origin/main (this run): 52b99f347eb7a0949a045e64c914a9bb176e60fd  (merge of PR #66)
branch path:           feat/web-live-product-store-activation → PR #63
                       feat/web-live-store-qr → PR #65 / #66
```

# Store status

| Platform | Identity | Public status | Canonical URL | Verification |
|---|---|---|---|---|
| iOS | HiAir / `com.hiair.app` / id `6773610034` / seller Aleksandr Potkin / version 1.1 | `PUBLIC_CONFIRMED` | `https://apps.apple.com/us/app/hiair/id6773610034` | iTunes Lookup `resultCount=1`; public storefront US/ES/`/app/id6773610034` HTTP 200; Chrome listing title “HiAir App - App Store”; identity matches heat/air wellness |
| Android | package `com.hiair` (from `mobile/android/app/build.gradle.kts`) | `NOT_PUBLIC` | none | Play details HTTP 404; Chrome title «Не найдено»; Exa `CRAWL_NOT_FOUND`. Console/internal test ≠ public storefront |

Machine-readable source of truth: `web/config/store-links.json` (generated into `web/js/store-links.js`). Do not hand-edit the JS file.

# Website updates

Changed pages/components (PRs #63 + #65):

- `web/config/store-links.json` — canonical store truth (`ios.PUBLIC_CONFIRMED`, `android.NOT_PUBLIC`)
- `web/js/store-links.js` — generated runtime helper
- `web/js/store-links.test.cjs` — store URL / badge / pre-launch copy gates
- `web/index.html` — hero App Store badge, download block + QR, Android notify form, FAQ, footer
- `web/js/main.js` — hydrate verified CTAs; hide Play CTAs unless public
- `web/styles.css` — download panel, official badge, QR layout
- `web/assets/badges/download-on-the-app-store.svg` — official Apple badge
- `web/assets/badges/app-store-qr.svg` — QR payload `https://apps.apple.com/us/app/hiair/id6773610034`
- Generated content hub pages via `scripts/ops/generate_web_seo_content.py` (about, contact, guides, audience pages)
- `web/404.html`, `web/sitemap.xml`, `web/APP_STORE_UTM.md`
- SEO/route gates: `scripts/ops/check_web_seo.py`, `scripts/ops/check_web_local_routes.py`

# Removed stale claims

Production-facing phrases found on earlier `origin/main` / live site and replacements:

| Old (public) | New |
|---|---|
| Meta: “Join early access for iOS and Android.” | “Download HiAir on the App Store.” |
| JSON-LD `operatingSystem`: “iOS, Android” | `operatingSystem`: “iOS” only |
| Hero: waitlist / early-access framing | “Available on the App Store. Android is not publicly listed yet.” |
| Waitlist CTA: “Join early access” | “Notify me about Android” |
| FAQ: “When will early access be available?” | “Where can I download HiAir?” |
| Contact meta: “early-access information” | product support / App Store download help |
| About: “HiAir is preparing wider availability for iOS and Android” | “HiAir is on the App Store… An Android listing is not public yet.” |

JSON-LD `MobileApplication` uses `installUrl` / `downloadUrl` = canonical App Store URL. No invented `ratingValue`, `reviewCount`, or `offers.price`.

CSS/form ids still use the word `waitlist` (Android notify form only). That is not a user-facing “product is in development” claim.

# Link verification

| Source | CTA | Destination | Result |
|---|---|---|---|
| Production Pages HTML header | Download HiAir on the App Store | `https://apps.apple.com/us/app/hiair/id6773610034?utm_source=hiair_io&…&ct=app_store_cta_header` | PASS — CDP `href` from live Pages DOM |
| Follow of that CTA URL | App Store | final `https://apps.apple.com/us/app/hiair/id6773610034` titled “HiAir App - App Store”, developer Aleksandr Potkin | PASS |
| Hero / download / FAQ / footer | App Store badge / App Store | same canonical id `6773610034` | PASS — 5 HTTPS hrefs, no `#` |
| QR asset | Scan to open the App Store | payload comment + generator: canonical App Store URL | PASS |
| `https://apps.apple.com/us/app/hiair/id6773610034` | listing | HTTP 200 | PASS |
| `https://apps.apple.com/es/app/hiair/id6773610034` | ES storefront | HTTP 200 | PASS |
| `https://apps.apple.com/app/id6773610034` | locale-default | HTTP 200 | PASS |
| Google Play details | none on site | `https://play.google.com/store/apps/details?id=com.hiair` | NOT advertised; public listing HTTP 404 / «Не найдено» |

No `href="#"`, `javascript:void(0)`, or `play.google.com` details URLs on public HTML.

# Tests

```text
lint:            N/A (static HTML/CSS/JS); python3 -m py_compile on web ops scripts PASS
typecheck:       N/A (no TypeScript website)
tests:           node --test web/js/store-links.test.cjs web/js/growth-telemetry.test.cjs  → 9/9 pass
build:           python3 scripts/ops/generate_web_seo_content.py drift-free; check_web_seo PASS (13 URLs); check_web_local_routes PASS (23 routes + 404)
E2E:             no website Playwright suite; Chrome + HTTP + Exa on production artifacts
CI validate:     hiair-io-pages run 33263349858 (PR #63) SUCCESS
                 hiair-io-pages run 33263715200 (PR #65) SUCCESS  2026-08-29T16:43:35Z
```

# Production verification

```text
deployment ID:   GitHub Actions run 33263715200 (QR + CTA follow-up on main)
commit SHA:      f48b1044a44a1bae0515b96eaf043ed4a706a8a0
Pages URL:       https://hiair-web.pages.dev/
timestamp:       2026-08-29T16:43:35Z
status:          validate SUCCESS + deploy SUCCESS (Cloudflare Pages project hiair-web)
hiair.io HTTP:   Exa fetch of https://hiair.io/ after deploys shows live-product copy
                 (Available on the App Store. Android is not publicly listed yet.)
                 Local curl / Cursor Chrome to apex timed out
desktop:         docs/reports/evidence/2026-08-29-desktop-homepage.png
                 docs/reports/evidence/2026-08-29-pages-desktop-hero-qr-deploy.png
mobile:          docs/reports/evidence/2026-08-29-mobile-homepage.png
download block:  docs/reports/evidence/2026-08-29-desktop-download.png
App Store:       docs/reports/evidence/2026-08-29-app-store-listing-hiair-id6773610034.png
Play (not public): docs/reports/evidence/2026-08-29-google-play-com-hiair-not-found.png
QR asset:        docs/reports/evidence/2026-08-29-app-store-qr-asset.png
App Store click: production Pages header href → apps.apple.com/us/app/hiair/id6773610034
Google Play:     not advertised
```

Local `curl` to `https://hiair.io/`, `https://www.hiair.io/`, and even `https://api.hiair.io/health` from this agent host timed out. Cloudflare Pages origin, Exa, and the public App Store storefront succeeded. Treat apex TCP timeout as an agent-network limitation, not as proof the apex is down for consumers.

# Remaining blockers

1. **Google Play is not a public listing**  
   - **Source:** HTTP 404 on `https://play.google.com/store/apps/details?id=com.hiair` (2026-08-29); Chrome «Страница не найдена». Console/internal testing is not a public storefront.  
   - **Impact:** Website correctly does not show a Play badge or “Download on Google Play”. Product is iOS-only for consumers.  
   - **Exact next action:** Owner publishes a production Play Store listing for `com.hiair`, then set `web/config/store-links.json` `android.status` to `PUBLIC_CONFIRMED` with the verified URL, run `python3 scripts/ops/generate_web_seo_content.py`, and redeploy Pages.

2. **Agent host cannot reliably TCP-connect to apex `hiair.io`**  
   - **Source:** `curl --max-time 25 https://hiair.io/` → timeout; Cursor IDE browser `chrome-error://chromewebdata/`. Exa and Pages origin work.  
   - **Impact:** Interactive click-through was executed on the identical production Pages artifact and by following the live DOM `href`, not on the apex hostname in this Chrome profile.  
   - **Exact next action:** Optional: from a normal consumer network, open `https://hiair.io`, click header “Download on the App Store”, and confirm the HiAir listing (Aleksandr Potkin, id 6773610034).

# Store identity verification

## iOS

```text
Store URL:              https://apps.apple.com/us/app/hiair/id6773610034
App name:               HiAir
Subtitle:               Air quality, pollen & heat
App ID:                 6773610034
Developer / seller:     Aleksandr Potkin
Bundle ID:              com.hiair.app
Version:                1.1
Minimum OS:             iOS 16.0
Category:               Health & Fitness
Release / update:       first public 2026-08-25; current version 2026-08-26T05:00:59Z
Public availability:    PUBLIC_CONFIRMED (US default + ES storefront; GET / View in Mac App Store present)
Verification method:    iTunes Lookup API + public storefront HTTP 200 + Chrome listing + production CTA href follow
```

## Android

```text
Store URL:              none (not public)
App name:               HiAir (intended)
Package ID:             com.hiair
Developer:              not observable on a public listing
Version/update:         not observable on a public listing
Public availability:    NOT_PUBLIC
Verification method:    Gradle applicationId + Play details HTTP 404 + Chrome «Не найдено» + Exa CRAWL_NOT_FOUND
```
