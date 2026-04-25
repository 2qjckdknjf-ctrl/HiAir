# Push E2E QA Checklist

## Preconditions

- [ ] Staging backend is running.
- [ ] User can sign up or log in from mobile app.
- [ ] `NOTIFICATION_ADMIN_TOKEN` is configured for provider health endpoints.
- [ ] APNs credentials are configured for iOS live delivery. Status: BLOCKED_EXTERNAL.
- [ ] FCM credentials/config are configured for Android live delivery. Status: BLOCKED_EXTERNAL.

## iOS QA

- [ ] Install app on physical device.
- [ ] Log in with beta account.
- [ ] Accept notification permission prompt.
- [ ] Confirm APNs device token is uploaded to `/api/notifications/device-token`.
- [ ] Trigger high-risk dispatch from backend.
- [ ] Confirm notification delivery on device.
- [ ] Confirm `/api/notifications/delivery-attempts` records attempt.

## Android QA

- [ ] Install app on Android 13+ physical device.
- [ ] Log in with beta account.
- [ ] Accept notification permission prompt.
- [ ] Confirm FCM token is available and uploaded to `/api/notifications/device-token`.
- [ ] Trigger high-risk dispatch from backend.
- [ ] Confirm notification delivery on device.
- [ ] Confirm `/api/notifications/delivery-attempts` records attempt.

## Failure handling

- Permission denied: app must continue without crash and keep settings usable.
- Missing credentials: provider health should report missing config; beta report status is BLOCKED_EXTERNAL.
- Backend/API unavailable: token upload may fail silently but app must remain usable.
