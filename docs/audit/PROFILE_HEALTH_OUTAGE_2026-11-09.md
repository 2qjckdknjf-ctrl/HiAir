# Profile / Health recovery — 9 November 2026

## Confirmed outage

The user supplied two physical-device screenshots: profile bootstrap failed and Health consent save failed. The screenshots alone do not identify the installed build. At investigation time the iPhone was unavailable to device tools.

Production Supabase project `hiair-prod` (`qhxesaemlhzwbunpqjoo`) reported `INACTIVE`. A read-only SQL request failed with `Database is possibly not accessible at the moment`. The authorized project resume attempt failed with `PaymentRequiredException`: `This organization has unpaid invoices. Settle outstanding payments before trying to restore project.` No database contents, subscription ownership or health consent were altered.

The API liveness endpoint still reported `status=ok`, source `3ac1596ee8dc9ffdf6555958a2c373fbb585ce1c`, application fingerprint `0da0811b532be44a5ca7025598abadbd1ea67e0ab172ba416fda5e36095c7c90`. Liveness does not check database availability and is NOT evidence that profiles/consent work. Empty Supabase log/advisor results while the project is inactive are not a clean bill of health.

## Independent client correction

- A failed profile lookup now says that the profile could not be loaded; it does not claim the profile is absent. Server errors use service-unavailable copy, not generic network/create failure.
- Health consent failures distinguish server, network and authentication errors. A server failure no longer displays instructions to change Apple Health permissions.
- Retry after a failed save reuses the same owner's recorded system authorization and retries consent persistence. Upload remains blocked until server save succeeds. Health scope is unchanged.
- New explanatory copy is localized in RU/EN/ES/IT/FR.

## Verification / delivery boundary

255 iOS unit tests passed, including an integrated APIClient → HealthKitService 503 → retry 200 sequence: system authorization retained, no durable consent or upload on failure, exactly two consent POSTs, only the correct owner becomes connected. Two RU/EN profile-bootstrap UI tests passed with strict visible-message assertions.

Evidence: `/tmp/hiair-307-profile-health-verified.xcresult` and matching log. These are simulator checks; physical recovery evidence is recorded separately below.

The initial local candidate has been superseded by the reviewed, clean-source IPA described in the final delivery section below. Its generated sidecar was not rewritten.

## Recovery boundary

The invoice and resume blockers described above were resolved as recorded below. No replacement project, user-data migration, or subscription ownership change was needed. The database recovery restored server access; the client correction improves failure handling and retry, and does not itself repair a billing outage.

## Database recovery after owner payment

On 9 November at approximately 14:13–14:18 Europe/Madrid, the owner confirmed payment and the existing project resume request returned success. Status progressed INACTIVE → COMING_UP → ACTIVE_HEALTHY. Read-only SQL at 13:18:44 UTC confirmed one profile and one active Health consent for the current account; the prior consent timestamp was preserved. No user records or ownership mappings were edited.

The first test runner attempt did not initialize: iOS returned LocalAuthentication cancellation while a phone call was active. This is NOT an application test result.

## Physical recovery verification

On 9 November, iPhone 17 Pro / iOS 27.2 (24B119), cellular 5G, observed Russian UI:

- Build 306 initially still showed a dashboard error after DB resume. This failed result is retained in `/tmp/hiair-306-db-recovered-dashboard-retry.xcresult`; its exact request failure was not captured, so a specific cause is not asserted.
- Health connection then passed on 306. Server readback confirmed active consent updated at 13:40:04 UTC and aggregate upload at 13:40:10 UTC. The successful result was persisted for the current account, not only displayed optimistically.
- Dashboard subsequently passed four launches on 306. Launch-to-visible-risk measurements were 7.105, 7.133, 7.128 and 7.198 seconds, including app launch and test UI interaction. The first correlated network response took 4.308 seconds. The UI correctly labeled the provider result as cached; this is not a new live-provider latency claim.
- Installed the development-signed 1.2 (307) candidate over 306 without deleting app data. Device metadata independently confirmed version/build. Dashboard and Health connection both passed in `/tmp/hiair-307-physical-recovery.xcresult`. Launch-to-visible-risk was 6.113 seconds. Health consent persisted at 13:45:46 UTC; aggregate summaries updated at 13:45:52 UTC, with 11 daily rows present. No raw health values were exported into this report.
- Source for that installed candidate: `42e3e558077d452f46ac79c381050598dca11bcc`. Screenshot/hierarchy and latency attachments: `/tmp/hiair-307-physical-attachments/`; device metadata: `/tmp/hiair-307-installed-metadata.json`.

These samples establish recovery on the connected phone, not p95 performance, offline/account-switch coverage, or a TestFlight installation. Dynamic Type, Motion/Transparency and accessibility acceptance were not newly measured here. Monthly/yearly purchase, restore, and the prior TestFlight ownership conflict remain separate open scenarios; no entitlement transfer or purchase was performed in this recovery pass. Android was not physically tested.

The protected checks, merge, release guard and TestFlight processing/internal availability are now complete; installation of the uploaded binary remains pending as detailed below.

## Review follow-up

PR100 review found outage title/body incorrectly applied to auth, profile-limit and cancellation outcomes. Adopted published correction `8d2c5274e21e0a5aab3166221648c01a959b40b6`: lookup-failure copy now requires the list phase and a retryable lookup outcome. New 402/403 UI assertions both failed before the fix (`/tmp/hiair-307-nonoutage-before.xcresult`) and passed after it. Full follow-up: **256 unit + 8 profile UI tests passed**, including RU/EN 503, 401 return to Auth, missing location, successful creation, and actionable 402/403 recovery (`/tmp/hiair-307-reviewed-regression.xcresult`). No required test was skipped or relaxed.

Three further physical 307 dashboard launches before this presentation-only follow-up passed at 6.960, 6.963 and 6.990 seconds (`/tmp/hiair-307-physical-repeat.xcresult`). They are preserved as measurements of that earlier installed source, not of a later TestFlight binary. The final IPA must be rebuilt after the review correction.

First GitHub iOS run `42628688983` failed before unit execution: simulator boot stalled in LaunchServices data migration and exceeded the bounded timeout. Logs: `/tmp/hiair-307-ci-first-diagnostics/hiair-simulator-boot.log`. An unchanged retry was requested; this infrastructure failure is not counted as an application test PASS.

The retry reproduced the same LaunchServices migration timeout on the same image-provided simulator UUID. CI preparation now creates a fresh simulator with the selected device's exact type and runtime instead of migrating its existing data. It does not erase existing devices, change the test suite, relax boot/test timeouts, skip tests, or change the all-passed/zero-skipped result gate. Unit checks cover matching runtime/type, missing metadata and malformed creation output; the actual CI run remains the acceptance criterion.


## Final checks and TestFlight delivery

- Final PR100 head `3252b6b4c2d39bccedcef7f8836b97daa8378e74`: [iOS CI](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/42632571397) SUCCESS (256 passed, zero failed/skipped); [Android CI](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/42632571881) SUCCESS; [backend smoke/gates](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/42632571841) SUCCESS; Security Reviewer SUCCESS. The fresh simulator initialized and executed the unchanged unit suite. The old Autofix check on a superseded head was still marked IN_PROGRESS; it is not represented as completed.
- [PR100](https://github.com/2qjckdknjf-ctrl/HiAir/pull/100) merged normally at 14:27:36 UTC as `38c6ba9979a983ad51c849c864f8e3234a93e2d0`, without bypass/admin. Reviewed profile-copy thread resolved only after the failing-before/passing-after UI checks.
- Uploaded source `23bb0b7e1487508998302481a9ef465c854efb48`, clean source. Its mobile tree matches final CI head and merge; the later commit changes only CI/docs. Exported IPA signature verification and HealthKit packaging checks PASS. IPA SHA256 `f480a43d1b429062a431fc1471c6c587b8889f3cd2019e1328482af5fb58273e`.
- The standard release guard passed against fresh origin/main ancestry and live backend fingerprint. Backend source remains `3ac1596ee8dc9ffdf6555958a2c373fbb585ce1c`, matching the unchanged backend tree. No backend deployment or schema migration was performed in this recovery.
- Upload succeeded at 14:29:48 UTC. ASC delivery/build ID `2031a9aa-8bbe-4997-8f5c-fd7b172f43fb`; ASC uploaded date 14:30:34 UTC. Processing **VALID**, internal state **IN_BETA_TESTING**. Reverse group-membership readback confirmed 307 in existing internal group **вт** (`827c14b0-82d8-40a2-b15b-11c498279ef9`), with no pagination omitted. External state remains READY_FOR_BETA_SUBMISSION; no public submission.
- Durable source/IPA/CI/store/device receipt: [RELEASE_MANIFEST_307_2026-11-09.json](../release/RELEASE_MANIFEST_307_2026-11-09.json). The build-generated IPA sidecar remains untouched.

## Remaining acceptance

The iPhone disconnected after development-build checks. TestFlight installation of the uploaded source is **not yet confirmed**. Reconnect/unlock, install 1.2 (307) from TestFlight without deleting app data, independently check distribution/build, then repeat dashboard and Health persistence checks. Do not relabel development-signed 307 evidence as TestFlight evidence.

Both App Store products are APPROVED with actual pricing/availability records, but this is catalog evidence only. Monthly/yearly purchase, restore and the exact prior TestFlight conflict transaction remain open. No repeat purchase, subscription transfer or direct consent edit was performed. Full offline/account-switch/accessibility coverage and physical Android remain unverified.
