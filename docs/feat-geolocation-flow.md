# Geolocation Flow Architecture (2026-07-14)

## Canonical location source

| Source | Meaning |
|--------|---------|
| `device` | GPS from CLLocationManager / FusedLocationProviderClient |
| `cached` | Hydrated from backend profile `home_lat`/`home_lon` |
| `manual` | Reserved (not implemented) |
| `unknown` | No valid coordinates |

## End-to-end flow

```
Permission explanation (onboarding step 5)
  → requestWhenInUseAuthorization / runtime permissions
  → one-shot location fetch (requestLocation / getCurrentLocation)
  → GeoCoordinates validation (no 0,0, accuracy + freshness)
  → PATCH /api/profiles/{id} home_lat/home_lon (or POST on first profile)
  → dashboard + planner reload via profileId (backend uses profile coords)
```

## Backend contract

- `POST/PATCH /api/profiles` — rejects `(0,0)` null island
- Air endpoints (`/api/air/current-risk`, `/api/air/day-plan`, briefing) — read `profile.home_lat/home_lon`
- Analytics — permission status, success/failure, source type, accuracy bucket only (no lat/lon)

## iOS

- `HiAir/Services/LocationService.swift` — singleton, delegate, timeout, states
- `AppSession` — no hardcoded Barcelona; `bootstrapLocationFromDevice()`, `syncProfileLocationIfNeeded()`
- TestFlight: CFBundleVersion **15** (post-fix)

## Android

- `com.hiair.location.LocationController` + manifest permissions
- `SettingsViewModel.ensureProfile()` — no profile create until valid coords

## Device verification required

Physical iPhone: fresh install → Allow → profile updated → dashboard `source=live` for real area.
