# HiAir — Final Release Program Status

**Updated:** 2026-07-21 (device certification refresh)  
**Branch:** `main` @ `106f30e` (docs) / product polish `fa0d91b`  
**Production SHA:** `fa0d91bcd294a779584daaf0ba6ed16751b6b065`  
**Health Intelligence:** PRODUCTION LIVE (schema + API); **device HealthKit E2E NOT VERIFIED**  
**TestFlight:** build **92** VALID (`cbd0b02f-3f78-42e8-a939-945210419d8a`)  
**Device certification:** **DEVICE CERTIFICATION IN PROGRESS**

---

## Engineering closed

| Area | Status | Evidence |
|------|--------|----------|
| Production API | LIVE | health 200; SHA `fa0d91b` |
| Health routes unauth | LIVE | summary/insights **401**; taxonomy **200** |
| Migrations 018/019 | LIVE | hiair-prod `health_intelligence` + soft-delete |
| Product polish | MERGED | Health grid, Android first-run, Premium locked UX (`fa0d91b`) |
| Backend pytest + final gate | PASS | `hiair_final_gate.sh` PASS (arm64 JDK resolution) |
| iOS build 92 | DISTRIBUTED | TestFlight VALID + physical reinstall/launch |
| Android assemble/lint/test | PASS | No physical Android attached |

## Operator certification required

| Area | Status | Owner action |
|------|--------|--------------|
| iPhone interactive E2E | IN PROGRESS | Checklist in `docs/release/qa/REAL_DEVICE_QA_REPORT.md` on **TF 92** |
| Maestro on physical device | BLOCKED (tooling) | Needs USB (or Maestro driver that sees CoreDevice network UDID) |
| Android device QA | EXTERNALLY BLOCKED | No USB device; Play Billing may remain blocked without Play Console app |
| StoreKit sandbox purchase | NOT RUN | Retest on TF 92 |
| Accessibility device audit | NOT RUN | Dynamic Type / VoiceOver / Dark Mode |

## Release configuration

| Build | API base |
|-------|----------|
| Android debug | `http://10.0.2.2:8000` |
| Android release | `https://api.hiair.io` |
| iOS debug | `http://127.0.0.1:8000` |
| iOS release / TestFlight | `https://api.hiair.io` |

Device certification against production **must use TestFlight** for StoreKit.

## Commits

- `fa0d91b` — fix: polish first-user product UX and health metrics surfaces (build 92)
- Gate fix (pending commit): arm64 JAVA_HOME for Android step in `hiair_final_gate.sh`

See `docs/release/qa/REAL_DEVICE_QA_REPORT.md` for the live matrix.
