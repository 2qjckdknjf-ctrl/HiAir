# Website → App Store UTM convention

Canonical store identity lives in `web/config/store-links.json`.
`web/js/store-links.js` is generated from that file. Do not duplicate URLs by hand.

Stable query parameters for every official App Store CTA on hiair.io:

| Param | Value | Notes |
| --- | --- | --- |
| `utm_source` | `hiair_io` | Always the marketing site |
| `utm_medium` | `website` | Owned web |
| `utm_campaign` | `app_store_cta` | Campaign family |
| `utm_content` | `header` / `hero` / `final` / `guide` / `footer` / `faq` | Placement |
| `ct` | `app_store_cta_{placement}` | Apple campaign token |

Canonical destination (iOS `PUBLIC_CONFIRMED`):

`https://apps.apple.com/us/app/hiair/id6773610034`

Android is `NOT_PUBLIC`. Do not emit a Google Play details URL until `android.status` is `PUBLIC_CONFIRMED`.

Growth OS events:

- `app_store_cta.viewed`
- `app_store_cta.clicked`

Properties: `page`, `placement`, `locale`, `campaign`. No personal or health data.

Chain (within provider limits): landing page → App Store click → acquisition → activation.
