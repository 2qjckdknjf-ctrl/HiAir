# Wearable Activity — Privacy & Store Report

## Documents Updated

- `docs/privacy-policy-draft.md` — Health & Activity section
- `docs/terms-of-service-draft.md` — optional health integration disclaimer
- `docs/store-metadata-packet.md` — privacy label row + store checklist items

## Disclosures

**Collected (with consent):** steps, heart rate aggregates, resting heart rate aggregates.

**Not collected:** raw continuous HR stream, clinical diagnoses.

**Purpose:** personal wellness load analysis during heat/AQI events.

**Controls:** connect, skip, disconnect, delete summaries, OS revoke.

## Store Checklist

- [ ] App Store Privacy Labels — Health/Fitness
- [ ] Google Play Data Safety — Health & fitness, encrypted in transit
- [ ] iOS `NSHealthShareUsageDescription` in `project.yml`
- [ ] Android Health Connect permission rationale in UI copy
- [ ] No emergency/medical claims in store metadata

## GDPR Alignment

- Explicit consent before collection
- Data minimization (aggregates)
- Export includes wearable tables
- Delete endpoint + account deletion cascade
