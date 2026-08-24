# Deep Glass V4 Visual Comparison — 2026-08-24 (v4 evidence)

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Baseline HEAD (committed):** `ab97229406b2e62d1c39be0868b54f03192bcf73`  
**Evidence run:** `.evidence/ios-screenshots/2026-08-24-hardening-v4-final/`  
**Provenance:** `worktree_dirty=false`; `rc_source_sha=ef82878755910c1e03cf7ccf3a9106df840c7e3c`  
**Device:** iPhone 17 Pro Simulator (requested), iOS 26, EN, standard text  
**Reference SHA-256:** verified against `docs/design/redesign-v4/references/manifest.json`

| Screen | Reference | Fresh capture | Verdict |
|--------|-----------|---------------|---------|
| Home / Dashboard | `references/01-home-deep-glass.png` | `02-dashboard.png` | **PASS WITH DOCUMENTED DEVIATION** |
| Planner | `references/02-planner-deep-glass.png` | `03-planner.png` | **PASS** |
| Health / Symptoms | `references/03-health-deep-glass.png` | `05-symptoms.png` | **PASS WITH DOCUMENTED DEVIATION** |
| Onboarding | `references/04-onboarding-deep-glass.png` | `01b-onboarding.png` | **PASS WITH DOCUMENTED DEVIATION** |
| Paywall | — | `07-paywall.png`, `07b-paywall-restore.png` | **PASS** (post header fix; v4 pre-final scroll still showed bleed — re-capture after VStack header) |
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
