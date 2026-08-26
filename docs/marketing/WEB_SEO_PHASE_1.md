# HiAir web search foundation — Phase 1

Date: 2026-08-25  
Scope: `web/`, Cloudflare Pages workflow, web-only validation scripts  
Production domain: `https://hiair.io`

## Outcome

The single landing page has been expanded into a crawlable, internally linked content hub while preserving the Deep Glass V4 visual system and the existing waitlist API flow.

### Indexable routes

- `/`
- `/guides/`
- `/guides/aqi-explained/`
- `/guides/exercise-in-heat/`
- `/guides/when-to-open-windows/`
- `/for-families/`
- `/for-runners/`
- `/air-quality-sensitive/`
- `/methodology/`
- `/about/`
- `/contact/`
- `/privacy/`
- `/terms/`

Every sitemap route has a unique title, meta description, canonical URL and one H1. Content pages include Open Graph/X metadata and JSON-LD. The health and safety content remains wellness-only and links to primary public-health sources.

## Crawl and platform controls

- `robots.txt` allows crawling and advertises the canonical sitemap.
- `sitemap.xml` lists all 13 canonical routes.
- `site.webmanifest` and branded icons are available.
- `_headers` adds baseline security, privacy and caching headers for Cloudflare Pages.
- `404.html` prevents broken paths from becoming low-quality indexed pages.
- The Pages workflow validates generation, SEO integrity, and local routes on pull requests. Production deploy still runs only after a successful validate job on `main` (push or intentional `workflow_dispatch`), never from a pull request.

## Regression gate

Run:

```bash
python3 scripts/ops/generate_web_seo_content.py
git diff --exit-code -- web
python3 scripts/ops/check_web_seo.py
python3 scripts/ops/check_web_local_routes.py
```

The gate fails on generator drift, missing sitemap files, duplicate titles/descriptions/H1s, canonical mismatches, missing Open Graph or X metadata, invalid JSON-LD, fake prices or ratings, broken internal links, orphan index pages, crawl blocking, public legal placeholders, or overclaiming “safe for your body” copy.

## Required owner/production actions after merge

1. Confirm the Cloudflare Pages production deployment finished on the merge commit.
2. Open `https://hiair.io/robots.txt` and `https://hiair.io/sitemap.xml` and confirm `200`.
3. Add/verify the `hiair.io` domain property in Google Search Console through a DNS TXT record.
4. Submit `https://hiair.io/sitemap.xml` in Search Console.
5. Inspect `/`, `/guides/aqi-explained/`, `/for-families/`, and `/methodology/`, then request indexing.
6. Add Bing Webmaster Tools by importing the verified Search Console property or verifying DNS, then submit the same sitemap.
7. Do not add public App Store or Google Play buttons until each store URL resolves without an authenticated tester account.

Search visibility is not instantaneous. This release makes the site eligible to be crawled and understood; indexing and ranking still depend on discovery, content quality, links, regional demand and time.

## Next governed slices

1. English/Spanish localization with real `hreflang` pairs.
2. Production store links and campaign attribution after public store availability is verified.
3. Carefully curated city pages backed by live, timestamped API data; no thin or synthetic programmatic pages.
4. Search Console query/page reporting and a content refresh cadence.
