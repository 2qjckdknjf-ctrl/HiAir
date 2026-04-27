# Push failure matrix

| Symptom | Likely cause | Fix | Type |
| --- | --- | --- | --- |
| iOS log: permission denied | User tapped “Don’t Allow” | Re-enable in iOS Settings → Notifications → HiAir | NEEDS_MANUAL_QA |
| iOS: no `token upload attempted` on device | Not signed in / no bearer token | Sign in; confirm Keychain token | INTERNAL_FIXABLE |
| iOS: `upload_failed` / OSLog error | HTTP 401/403/5xx from API | Check base URL, JWT expiry, backend logs | INTERNAL_FIXABLE / BLOCKED_BY_ENV |
| iOS simulator: never registers token | Simulator limitations for APNs | Test on physical device | NEEDS_MANUAL_QA |
| Android: `NO-OP — no cached FCM token` | No Firebase Messaging token persisted | Add FCM integration locally + `google-services.json` (not committed) | BLOCKED_EXTERNAL / INTERNAL_FIXABLE |
| Android: permission loop | POST_NOTIFICATIONS denied | Settings → Apps → HiAir → Notifications | NEEDS_MANUAL_QA |
| Backend: 422 on device-token | Bad `platform` | Must be `ios` or `android` lowercase | INTERNAL_FIXABLE |
| Backend: 403 profile | `profile_id` not owned by user | Omit profile or fix profile id | INTERNAL_FIXABLE |
| Backend: dispatch succeeds but no push | Provider mode `stub` or missing FCM/APNs secrets | Configure provider secrets in deployment env | BLOCKED_EXTERNAL |
| Delivery attempts show provider error | Invalid/expired FCM/APNs credentials | Rotate keys per ops runbook | BLOCKED_EXTERNAL |
