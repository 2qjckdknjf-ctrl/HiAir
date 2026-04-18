# HiAir API Risk Level Contract

Last updated: 2026-04-18

## Problem

The codebase currently contains two risk domains:
- legacy `/api/risk/*` and related endpoints using `low|medium|high|very_high`
- air-domain `/api/air/*` and related flows using `low|moderate|high|very_high`

This document defines the compatibility rules and deprecation direction.

## Canonical values by domain

- Legacy domain canonical set: `low`, `medium`, `high`, `very_high`
- Air domain canonical set: `low`, `moderate`, `high`, `very_high`

## Compatibility bridge (current enforced behavior)

- Server accepts both `medium` and `moderate` in air-domain risk parsing where applicable.
- Recommendation and alert logic treat `medium` and `moderate` as the same risk band.
- Mobile UI rendering maps both values to the same visual severity.

## Mapping rule

- `medium` <-> `moderate` (equivalent severity band)
- Other levels map 1:1 (`low`, `high`, `very_high`)

## Deprecation direction

Short-term:
- Keep compatibility bridge active to avoid breaking existing clients and historical data.

Mid-term:
- Introduce explicit normalization at API boundary and telemetry on alias usage.
- Publish versioned contract note in release docs before removing aliases.

Implemented now:
- Legacy `/api/risk/*` responses normalize `moderate` -> `medium`.
- Air-domain `/api/air/*` responses normalize `medium` -> `moderate`.
- Alias usage telemetry is emitted in observability metrics (`risk_level_alias_counts`).

Long-term:
- Choose one canonical external term per API family in a versioned endpoint strategy.
- Remove alias acceptance only after mobile and partner clients are migrated and validated.
