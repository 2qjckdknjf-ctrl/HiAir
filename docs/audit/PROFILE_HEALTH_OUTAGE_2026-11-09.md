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

Evidence: `/tmp/hiair-307-profile-health-verified.xcresult` and matching log. These are simulator checks; no physical HealthKit, live consent write, production data recovery or subscription acceptance is claimed.

Build 307 is a local candidate. Its clean source and hash belong to the generated release manifest. No push, merge or TestFlight delivery is claimed for this correction while production data is unavailable.

## Required next step

The organization owner must settle the outstanding Supabase invoice. Then retry project resume, wait for ACTIVE_HEALTHY, verify database and authenticated profile/consent requests on the connected iPhone, and only then continue the protected delivery process. Do not create a replacement project, migrate user data, change subscription ownership or pretend a new IPA repairs the billing outage.

## Database recovery after owner payment

On 9 November at approximately 14:13–14:18 Europe/Madrid, the owner confirmed payment and the existing project resume request returned success. Status progressed INACTIVE → COMING_UP → ACTIVE_HEALTHY. Read-only SQL at 13:18:44 UTC confirmed one profile and one active Health consent for the current account; the prior consent timestamp was preserved. No user records or ownership mappings were edited.

The iPhone is connected with HiAir 1.2 (306). The first test runner attempt did not initialize: iOS returned LocalAuthentication cancellation while a phone call was active. This is NOT an application test result. The physical recovery tests and TestFlight 307 delivery remain pending.
