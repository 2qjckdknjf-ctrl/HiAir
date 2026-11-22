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
- STOP removes timers/listeners/observers and restores exact original DOM. Late asynchronous responses, repeated initialization and changed identity cannot reactivate stale treatment or attribution.
- Local Node/VM regression tests plus isolated native browser evidence. Test sink is loopback only; no production events, no localhost:3001 fallback, no visitor records, no external requests for fixture exercise.

## Release boundary
Prepare one draft PR only. Do not merge: hiair-io-pages.yml deploys changed web files on main automatically. No flags, schemas, credentials, production configuration, experiment records, outcome captures or publication change in this task.

Before any future rollout, separately reconcile Growth OS public projection: current raw variant config rejects placement while outcome materialization requires it. Also require a fresh approved experiment, valid sample/evidence plan, authoritative source and deliberate activation/release decision. Local client tests do not prove live collection or G2 readiness.
