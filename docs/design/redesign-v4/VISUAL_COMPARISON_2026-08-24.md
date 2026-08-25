# Deep Glass V4 Visual Comparison — 2026-08-24 (v4 evidence)

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Baseline HEAD:** `09b7823e`  
**Evidence run:** `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-en-v2/`  
**Provenance:** UDID-resolved simulator; host observed-environment gate  
**Device:** iPhone 17 Pro Simulator, iOS 26.2, EN, standard text  

| Screen | Reference | Fresh capture | Verdict |
|--------|-----------|---------------|---------|
| Home / Dashboard | `references/01-home-deep-glass.png` | `02-dashboard.png` | **PASS** — softer 18pt Aurora fade |
| Planner | `references/02-planner-deep-glass.png` | `03-planner.png` | **PASS** |
| Health / Symptoms | `references/03-health-deep-glass.png` | `05-symptoms.png` | **PASS WITH DOCUMENTED DEVIATION** |
| Onboarding | `references/04-onboarding-deep-glass.png` | `01b-onboarding.png` | **PASS WITH DOCUMENTED DEVIATION** |
| Paywall | — | `07-paywall.png`, `07b-paywall-restore.png` | **PASS** — atmospheric gradient behind NavigationStack |
| Settings | — | `06-settings.png` | **PASS** |

## Dashboard (`01-home` ↔ `02-dashboard`)

**Matches:** orb hero, spectrum bar, glass metric tiles, floating tab bar with cyan active state.

**Fixed in v4:** unified bottom content fade above tab bar (`HiAirMainTabBarBottomChrome`) — reduced text bleed through glass vs v3.

**Deviations:** marketing reference crop vs product simulator chrome (status bar, location pill, Live badge).

## Planner (`02-planner` ↔ `03-planner`)

**Matches:** date strip, forecast chart, activity windows, no connection-error banner.

**Verdict:** **PASS**

## Paywall (`07-paywall`, `07b-paywall-restore`)

**Matches:** localized EN copy, Monthly/Yearly priced cards, Restore, Terms/Privacy, auto-renew disclosure.

**Fixed:** sticky header outside `ScrollView` (no readable copy under status bar when scrolled to Restore).

**Verdict:** **PASS**

## Settings (`06-settings`)

**Matches:** store-facing subtitle without observability; dark native form chrome.

**Verdict:** **PASS**

## Outstanding matrix (not claimed PASS)

- iPad 13" device class captures  
- RU / ES / IT / FR locale captures  
- Accessibility3 / Accessibility5  
- Reduce Transparency / Reduce Motion  
- Android phone/tablet comparison register (in progress)

**Overall iPhone EN standard-text verdict:** **PASS WITH DOCUMENTED DEVIATIONS** — no open P0 visual blockers on v4 captured set after paywall header fix (re-capture recommended for manifest parity).
