# External Proof Request Packet

Last updated: 2026-04-22

Use this packet to request final external artifacts required for EXT closure.

## Required from Product/Platform owners

### EXT-001 (#2) App Store Connect
- Access proof (account/role visibility)
- TestFlight upload confirmation
- Tester invite/distribution evidence

### EXT-002 (#3) Play Console
- Access proof (account/role visibility)
- Internal track release confirmation
- Tester availability proof

### EXT-005 (#6) Store metadata/compliance
- Final screenshot set artifact
- Final localized store copy artifact
- Final privacy/compliance answers artifact
- Reviewer notes final copy

## Required from Legal owner

### EXT-003 (#4) Legal signoff
- Signed legal review artifact
- Final Privacy Policy public URL
- Final Terms public URL

## Required from Security/Ops owner

### EXT-004 (#5) Secrets governance
- Secret inventory artifact
- Rotation policy approval artifact
- Access model approval artifact

## Submission instruction

- Attach artifacts directly in each EXT issue thread (#2-#6).
- Replace `[ADD]` placeholders in final evidence form comments.
- Re-run:
  - `python3 backend/scripts/check_external_blocker_closure_readiness.py`
  - `python3 backend/scripts/check_external_blocker_evidence_completeness.py`
- Close issues only after both gates pass.
