# Symptom Taxonomy

Canonical catalog lives in `backend/app/services/symptom_taxonomy.py` and is served by:

`GET /api/v1/health/symptoms/taxonomy`

## Categories

| Category | Approx. count | Notes |
|----------|--------------:|-------|
| respiratory | 11 | Includes red-flag dyspnea / air hunger |
| allergy_nose_throat | 9 | |
| eyes | 6 | |
| heat_dehydration | 11 | Heat red flags included |
| head_nervous | 10 | Confusion is red-flag |
| cardiovascular_sensation | 6 | Subjective sensations only |
| general | 8 | |
| sleep_recovery | 7 | |
| skin | 6 | |
| digestion | 5 | No automatic air/heat linkage |
| custom | user-defined | |

Total built-in symptoms: **70+**

## Entry fields

severity (1–5), onset, duration, ongoing, frequency, body/location context,
optional suspected trigger, activity at onset, hydration, medication taken (yes/no),
note, timezone, profile.

## Safety

Red-flag symptoms return `safetyNotice` asking the user to seek emergency help when appropriate.
No diagnosis. No urgency scoring algorithm.
