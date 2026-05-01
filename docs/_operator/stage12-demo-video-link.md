# Stage 12 Demo Video Link

Status: blocked on local simulator runtime.

## Attempt log (automated)

- 2026-05-01 UTC: attempted iOS simulator recording via `simctl`.
- Failure: `Unable to boot the Simulator. launchd failed to respond.`
- Underlying error: `Failed to start launchd_sim: could not bind to session`.

## Recorder helper

- Script: `backend/scripts/record_stage12_demo_ios.sh`
- Expected output path: `docs/_operator/stage12-demo-ios.mp4`

## To finalize this artifact

Run on a machine where iOS Simulator can boot:

```bash
backend/scripts/record_stage12_demo_ios.sh
```

Then replace this file with:

- recording date/time (UTC)
- owner
- storage link/path
- checksum or immutable reference
- short note listing covered flows (Dashboard, Planner, Symptoms, Insights, Settings/Briefings)
