# Device QA Checklist — Health Intelligence

## Verdict gate

`HEALTH DATA + SYMPTOMS + ANALYTICS E2E VERIFIED` is forbidden without physical device evidence for both platforms.

## iOS (physical iPhone)

1. Connect Apple Health; grant activity+sleep, then heart.
2. Confirm real steps / HR / sleep appear (not zeros for missing).
3. Partial revoke one category → UI shows unavailable / no records honestly.
4. Sync → backend `/api/v1/health/summary` has rows.
5. Log 5+ symptom types across categories; red-flag shows safety notice.
6. Insights show today / trends / associations / insufficient progress.
7. Restart app → last sync + values persist.
8. Delete health data from Settings → summaries gone.

## Android (physical device + Health Connect)

1. Health Connect installed/updated.
2. Grant selected record types.
3. Confirm real values; RMSSD labeled separately from SDNN.
4. Partial permission + revoke paths.
5. Sync, symptoms, insights, restart, delete.

## Known external blockers

- TestFlight / Play release not required for local device QA, but production API deploy is required for remote sync verification.
- Android Play Health Connect declaration required before Play production distribution.
