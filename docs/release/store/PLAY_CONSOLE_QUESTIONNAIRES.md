# Play Console questionnaires — HiAir 1.0 (188)

Fill these on **Policy → App content**. Do not click production publish until the owner verifies.

Checked against Play policies current as of **2026-08-21**.

## Already done (2026-08-11)

- Privacy policy URL: `https://hiair.io/privacy/`
- Government apps: **No**
- Ads: **No**
- App access: saved (provide demo login in Console, never in git)

## Advertising ID

- Does the app use the advertising ID? **No**
- Manifest explicitly removes `com.google.android.gms.permission.AD_ID`

## Target audience and content

- Designed for children? **No**
- Target age groups: **13–15, 16–17, 18+** (or the Console equivalent “13 and up”; do **not** select under-13)
- Appeal to children in store graphics? **No**
- News app? **No**
- Neutral age screen for mixed audiences: not applicable (not designed for children)

Accounts are 13+. In-app copy states this on auth/onboarding.

## Content rating (IARC)

Answer truthfully for a wellness planner with no UGC, violence, sex, or gambling:

- Violence: none
- Sexuality: none
- Language: none
- Controlled substances: none
- User interaction / sharing: private symptom journal only, not public UGC
- Digital purchases: **Yes** (auto-renewable subscriptions)
- Location sharing: approximate/precise location used for air/heat risk
- Unrestricted internet: yes (standard networked app)

Expected outcome: Everyone / PEGI 3 style rating depending on authority. Confirm the generated rating before submitting.

## Data safety

Use `docs/release/store/DATA_SAFETY.md`. Summary:

- Collects: email, user ID, location (approx + precise when granted), Health Connect aggregates (optional), symptom logs, device push token (optional)
- Purposes: app functionality, personalization (non-ads)
- Encrypted in transit: **Yes** (HTTPS)
- Users can request deletion: **Yes** (in-app Delete account + `POST /api/privacy/delete-account`)
- Independent security review: **No**
- Data sold: **No**
- Data shared with third parties for ads: **No**
- Advertising ID: **No**

## Health apps declaration

Declare wellness features, not medical:

- Fitness/activity tracking: **Yes** (optional Health Connect daily/hourly aggregates)
- Health information / symptoms: **Yes** (user-entered private journal)
- Medical advice / diagnosis / emergency: **No**
- Human subjects research: **No**
- Connected medical devices: **No**
- Copy: wellness-only; app remains usable if Health Connect is denied

## App category

Health & Fitness.

## Production publish

Internal track first (188). Production track only after owner confirmation.
