# Play public store-links flip (READY — do not merge until HTTP 200)

Branch: `chore/prepare-play-public-store-links`

## Gate
Only merge after:
```bash
curl -sI "https://play.google.com/store/apps/details?id=com.hiair" | head -1
# expect HTTP/2 200
```

## Files prepared
- `web/config/store-links.json` → `android.status=PUBLIC_CONFIRMED`
- `web/js/store-links.js` regenerated
- `web/js/store-links.test.cjs` updated for public Android

## After merge
- `hiair-io-pages` deploys on `web/**` push to main
- Confirm CTAs: `.js-play-store-cta` elements must exist in HTML for Play badges to appear (runtime removes them when not public; add badge markup in a follow-up if missing on live pages)
