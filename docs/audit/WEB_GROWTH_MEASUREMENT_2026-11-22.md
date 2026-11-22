# HIAIR-WEB-GROWTH-001 — experiment measurement preparation

Owner authorization 2026-11-22: prepare the HiAir website integration with experiments OFF and without a website release. This is a web-only continuation of existing helpers, not a new mobile feature or an experiment approval.

Base: origin/main fe831c6bab0668a6132c61d61a9df8d28ec33cc4. Reuse web/js/growth-experiment-{assignment,config,exposure,telemetry,runtime}.js. Dirty legacy and physical-device worktrees are preserved. The clean release checkout is reused on a new branch; its prior release branch and ignored artifacts are preserved. Two managed-worktree tool attempts stalled before creating any checkout and were stopped.

## Acceptance
- Homepage loads existing helpers in dependency order. Literal HIAIR_EXPERIMENTS_ENABLED=false remains compiled into main.js; no URL, storage or global override. OFF changes no CTA and makes no experiment request or experiment-storage write.
- Prepared integration targets only the header App Store CTA, preserving its exact original Download text, destination, attributes and existing aliases. Other six placements retain current behavior.
- Strict, bounded public config: product=hiair, surface=website, placement=header; exactly one matching candidate, valid two-arm allocation, safe public cta_copy only. Unknown/ambiguous/malformed config keeps CONTROL.
- Durable, anonymous-identity-bound sticky assignment uses browser Web Crypto SHA-256; missing/throwing crypto or storage keeps CONTROL even with a cached treatment. Independent visitor/reload and golden-vector checks remain meaningful.
- Confirm assignment receipt before applying treatment. A valid receipt is ok:true with consistent stored/duplicate booleans and status. HTTP success alone does not suffice. Configuration and telemetry waits are bounded.
- Observe >=50% visibility continuously for >=1000ms, including a stationary CTA with only one observer callback. Reset on hidden tab, loss of visibility, removal and stop. Count an exposure only after acknowledgement; click attribution is available only afterward.
- Send one canonical app_store_cta.clicked event through the existing main path: historical v1 before attribution or v2 afterward. Never send both or fallback on an ambiguous v2 response. Existing viewed remains page-presence and is not claimed as viewport exposure.
- STOP removes measurement timers/listeners/observers, cancels preparation requests, and restores exact original DOM. An already initiated conversion keeps its own bounded keepalive POST; stopping must not erase an action that already occurred. Late asynchronous responses, repeated initialization and changed identity cannot reactivate stale treatment or attribution.
- Local Node/VM regression tests plus isolated native browser evidence. Test sink is loopback only; no production events, no localhost:3001 fallback, no visitor records, no external requests for fixture exercise.

## Release boundary
Prepare one draft PR only. Do not merge: hiair-io-pages.yml deploys changed web files on main automatically. No flags, schemas, credentials, production configuration, experiment records, outcome captures or publication change in this task.

Before any future rollout, separately reconcile Growth OS public projection: current raw variant config rejects placement while outcome materialization requires it. Also require a fresh approved experiment, valid sample/evidence plan, authoritative source and deliberate activation/release decision. Local client tests do not prove live collection or G2 readiness.

## Implemented and verified preparation

The existing five helpers are loaded once before main.js. The header-only bootstrap remains source-disabled. Assignment storage is bound to anonymous identity and rechecks browser SHA-256 and durable storage; the bootstrap rejects legacy anonymous/session fallbacks. The exact original text is restored on stop/failure; nested header markup is rejected rather than flattened.

Public configuration is limited to one matching website/header experiment with two valid arms. Requests omit credentials, reject redirects, have a 5-second deadline, cap POST bodies at 8192 UTF-8 bytes and responses at 16384 bytes. Treatment waits for a consistent server JSON acknowledgement; exposure waits for continuous visibility and its own acknowledgement. Generation and cancellation guards prevent late responses from resurrecting stopped state. Version-bound SHA-256 IDs avoid old assignment-version/session collisions and remain within the server's opaque 200-character event ID contract.

The original main.js click path sends one canonical CTA click, v1 before attribution or v2 after acknowledged exposure. Existing aliases remain unchanged. A failed or uncertain v2 response stops this runtime without creating a v1 retry. Ordinary viewed events retain their historical page-presence meaning.

### Local validation, 2026-11-22
- All five web test suites: **50 passed, 0 failed, 0 skipped**. Includes 10,000 actual Web Crypto assignments and 1,000 identity-bound sticky visitors; both arms are asserted. Independent reviewer executed **38 focused tests**, all passed, with no blocking findings.
- SEO integrity: 13 sitemap URLs and unique titles PASS. Static routes: **28 plus expected404**, PASS. JavaScript/Python syntax and whitespace checks PASS.
- Native in-app browser with the actual homepage, local-only sink and real IntersectionObserver: OFF retained Download and exactly seven legacy v1 viewed events; no config/experiment request. ON recorded assignment at 14:39:38.897Z and stationary exposure at 14:39:39.906Z, then one canonical v2 click and the two unchanged v1 aliases. No duplicate canonical v1 click.
- Native STOP restored Download and the same App Store URL. Negative assignment and exposure acknowledgements restored/retained CONTROL without attribution. Desktop width1280 had no horizontal overflow.
- Native mobile390x844: hidden navigation produced assignment but no exposure; opening the menu produced acknowledged exposure. Navigation closed normally, no horizontal overflow; temporary viewport override was reset.
- A fixture inline-script escaping defect was fixed and covered by a real HTTP/JavaScript compilation regression before the final browser run. The corrected fixture had no new browser errors. Fixture-only panel presentation was made legible for evidence capture.

Reproduce: run the five web test suites from hiair-io-pages.yml, then `node scripts/ops/serve_growth_measurement_fixture.cjs`. It prints a loopback URL on a free port, provides OFF/ON/CONTROL/empty/negative-ack modes and never calls production. ON is a server-side substitution only in the served local copy; tracked main.js stays OFF. The fixture is outside web/ and is not a published asset. Full local traces and screenshots are retained in the requesting chat's work/hiair-growth-nov22 and outputs folders.

**Delivery state:** local preparation verified; draft PR only. Not merged, not deployed, no production settings or data changed. CI's deployment condition is unchanged; merging web changes to main would deploy the site and therefore remains outside this authorization. This evidence is not production experiment collection or G2 acceptance.

Prepared as [draft PR105](https://github.com/2qjckdknjf-ctrl/HiAir/pull/105), code commit `bdc5aae8f80a344af3ccc6a3de9974b3ce482dc4`. Web CI [45034423464](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/45034423464) passed on that code; its deploy job was skipped. The final local-only fixture servers were stopped after evidence capture.


## PR105 review follow-up — 2026-11-22

Bugbot finding [4658590672](https://github.com/2qjckdknjf-ctrl/HiAir/pull/105#discussion_r4658590672) identified that pagehide aborted the attributed conversion POST, despite keepalive. Its completed Autofix was inspected on the separate branch `cursor/pagehide-click-telemetry-631f`, commit `c84c6560ddd6c90a9b7cfbc9c80a9f15a5c5c1c3`; no additional PR existed at the inspection. That fix was reused and extended locally, preserving its source history.

An initiated v2 click now finishes through its own bounded keepalive transport, without the measurement runtime's abort signal. No fallback v1 event is sent. A cached page suspends the exposure clock and observation, and cannot supply attribution while frozen. On a persisted pageshow it checks identity and starts a new generation with fresh server configuration, assignment acknowledgement, and a fresh continuous visibility interval. This also prevents cached RUNNING configuration from reviving a server-stopped experiment. An explicit STOP removes the resume listener. A late rejection from the previous conversion cannot stop the new generation.

Local verification: **57 tests passed / 0 failed / 0 skipped**, including seven added page-lifecycle regressions; SEO **13 URLs**, routes **28 + 404**, syntax and diff checks passed. The new lifecycle cases use the actual homepage scripts with isolated transport and pagehide/pageshow events. They do not certify a physical iOS App Store handoff or actual browser bfcache admission. Earlier native-browser evidence above covers the original OFF slice, not this new lifecycle behavior. Source flag remains false; no site merge, release, activation or production event was performed.
