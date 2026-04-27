# App Store Privacy Labels Draft

Status: LEGAL_SIGNOFF_REQUIRED

This is a draft for legal/security review. Do not submit without signoff.

| Data category | Collected | Purpose | Linked to user | Used for tracking | Notes |
|---|---|---|---|---|---|
| Contact info - email | Yes | Account authentication | Yes | No | Required for account |
| Identifiers - user ID | Yes | App functionality/security | Yes | No | Internal ID |
| Location | Yes | Personalized heat/air risk | Yes | No | Manual coordinates in current app; Core Location not verified |
| Health/Fitness-like wellness data | Yes | Symptom log and recommendations | Yes | No | Wellness only, not medical diagnosis |
| User content | No | N/A | N/A | No | No UGC in MVP |
| Usage data | Partial | Reliability and beta QA | Partial | No | Request metadata/ops telemetry |
| Diagnostics | Partial | Crash/debug/ops | Partial | No | Current repo has backend logs/metrics, no full mobile crash SDK verified |

## Required before submission

- [ ] Legal confirms wellness-only positioning.
- [ ] Legal confirms controller/contact.
- [ ] Security confirms data retention/deletion mapping.
- [ ] Product confirms no tracking/ads SDKs.
- [ ] Final privacy policy URL is published.
