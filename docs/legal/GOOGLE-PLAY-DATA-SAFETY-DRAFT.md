# Google Play Data Safety Draft

Status: LEGAL_SIGNOFF_REQUIRED

This is a draft for legal/security review. Do not submit without signoff.

## Data collected

| Data type | Collected | Shared | Purpose | Deletion supported |
|---|---|---|---|---|
| Email address | Yes | No sale; infrastructure processors only | Account management | Yes |
| User IDs | Yes | No sale; infrastructure processors only | App functionality/security | Yes |
| Approximate/manual location | Yes | Weather/AQI providers may receive query coordinates when live mode is enabled | Personalized risk | Yes |
| Health/wellness inputs | Yes | No sale; backend processing | Recommendations and symptom history | Yes |
| Device or other IDs | Push token optional | Push providers when live notifications enabled | Notifications | Yes |
| App activity / diagnostics | Partial | Infrastructure processors | Reliability/security | Partial retention windows |

## Security practices

- Data in transit should use HTTPS/TLS for staging/production.
- Account deletion endpoint exists.
- Data export endpoint exists.
- Backend retention cleanup exists.

## Required before Play submission

- [ ] Legal confirms data categories.
- [ ] Final privacy URL is published.
- [ ] FCM live configuration decision is documented.
- [ ] Retention windows and deletion caveats are approved.
