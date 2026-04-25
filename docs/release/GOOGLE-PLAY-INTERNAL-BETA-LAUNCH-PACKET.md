# Google Play Internal Beta Launch Packet

Status: BLOCKED_EXTERNAL

## Required Google Inputs

- Google Play Console access: BLOCKED_EXTERNAL
- Package name: `com.hiair`
- Signing key / Play App Signing decision: BLOCKED_EXTERNAL
- Internal testing track: BLOCKED_EXTERNAL
- Tester emails: BLOCKED_EXTERNAL
- Privacy policy URL: LEGAL_SIGNOFF_REQUIRED
- Support URL: BLOCKED_EXTERNAL
- Data Safety answers: LEGAL_SIGNOFF_REQUIRED
- Screenshots: NEEDS_MANUAL_QA
- Short description: `Heat & Air Wellness Companion`
- Full description: READY_FOR_OWNER in `docs/release/STORE-LEGAL-METADATA-LAUNCH-PACKET.md`

## Local Commands

```bash
cd mobile/android
./gradlew clean
./gradlew assembleDebug
./gradlew assembleRelease
./gradlew bundleRelease
./gradlew lint
```

## Upload Checklist

- [ ] Confirm package name `com.hiair`.
- [ ] Decide Play App Signing vs self-managed signing.
- [ ] Produce signed AAB.
- [ ] Complete Data Safety form.
- [ ] Upload screenshots and descriptions.
- [ ] Create internal testing release.
- [ ] Add tester emails/group.
- [ ] Add release notes and known beta limitations.

## Current Local Evidence

- Android debug/release/lint: GO.
- `bundleRelease`: verify in Phase 3 final checks.
- Play upload: BLOCKED_EXTERNAL.
