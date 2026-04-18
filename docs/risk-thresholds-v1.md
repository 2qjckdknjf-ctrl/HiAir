# HiAir Risk Thresholds v1

This document fixes the initial rule-based threshold table used by the MVP risk engine.

## References

- WHO Air Quality Guidelines (AQG) 2021
- CDC public heat stress guidance
- Product-side conservative safety margins for sensitive personas

## Environmental threshold bands

### Temperature (`temperature_c`)
- `<29`: low contribution
- `29-32`: medium
- `33-37`: high
- `>=38`: very high

### AQI (`aqi`)
- `0-50`: low
- `51-100`: medium
- `101-150`: high
- `151-200`: very high
- `>=201`: severe

### PM2.5 (`pm25`)
- `<15`: low
- `15-34`: medium
- `35-54`: high
- `>=55`: very high

### Ozone (`ozone`)
- `<70`: low
- `70-89`: medium
- `90-119`: high
- `>=120`: very high

## Final score to risk level

- `0-34`: low
- `35-59`: medium
- `60-79`: high
- `80-100`: very high

## Notes

- Sensitive personas (`child`, `elderly`, `asthma`, `allergy`) use positive risk modifiers.
- Recent symptom logs increase risk via symptom modifier.
- This table is intentionally transparent and auditable before ML phases.
