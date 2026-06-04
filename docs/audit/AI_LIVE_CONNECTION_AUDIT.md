# HiAir AI Live Connection Audit

**Audit date:** 2026-06-04 (final + LEVEL 5 hardening)  
**Branch:** `main` @ `9ec4f79`  
**Auditor mode:** truth-based repo + runtime probes (no secrets exposed)

---

## 1. Executive Verdict

| Item | Result |
|------|--------|
| **AI status** | Live LLM **connected locally**; engineering hardening **in progress toward LEVEL 5** |
| **Classification level** | **LEVEL 4 — Live provider connected** |
| **Is OpenAI/LLM live connected** | **YES** — `check_ai_connection.py --require-live` **exit 0** |
| **Is fallback active** | **Degraded mode only** — historical fallback rows may remain in 24h window |
| **Is deterministic risk engine active** | **YES** |
| **Main blocker (LEVEL 5)** | ~~Staging/production secret injection~~ **Done**; run deploy workflow on staging/production to validate in-smoke `explanationSource=llm` |

### Authoritative gate (local, 2026-06-04)

| Check | Result |
|-------|--------|
| `backend/.env.local` `OPENAI_API_KEY` | **SET** (length=164, prefix=sk-***) |
| `provider_configured` | **true** |
| `llm_success_count` (24h DB) | **≥ 1** |
| `check_ai_connection.py` | **exit 0** |
| `check_ai_connection.py --require-live` | **exit 0** |

---

## 2. Evidence Matrix

| Area | Evidence | Status |
|------|----------|--------|
| AI service + OpenAI HTTP | `ai_explanation_service.py` | **Present** |
| Rate limit / cost caps | `OPENAI_RATE_LIMIT_PER_MINUTE`, `OPENAI_MAX_TOKENS`, timeout | **Added** |
| Local env key | `backend/.env.local` | **SET** |
| DB live event | `ai_explanation_events.used_fallback=false` | **Recorded** |
| `--require-live` gate | `check_ai_connection.py --require-live` | **PASS** |
| Seed helper | `scripts/seed_ai_live_probe.py` | **Added** |
| Smoke covers AI | `smoke_db_flow.py` → `/api/air/current-risk`, `ai-summary*` | **Added** |
| Backend gate | `run_backend_gate.py` → `check_ai_connection --skip-if-unconfigured` | **Added** |
| CI | `backend-ci.yml` gate (skip-if-unconfigured when no key) | **Wired** |
| Staging deploy | `OPENAI_API_KEY` / `OPENAI_MODEL` GitHub secrets | **Done** |
| Production deploy | `OPENAI_API_KEY` / `OPENAI_MODEL` GitHub secrets + workflow env | **Done** |
| Deploy gate | `deploy_backend.sh` smoke LLM assert + seed/require-live | **Added** |
| Mobile AI UI | Dashboard + Settings observability | **Integrated** |

---

## 3. AI Module Map

See prior sections: LLM layer = `ai_explanation_service.py` only; risk/recommendations/correlation = deterministic.

**Scripts:**

| Script | Purpose |
|--------|---------|
| `check_ai_connection.py` | Env + DB observability; `--require-live`, `--skip-if-unconfigured` |
| `seed_ai_live_probe.py` | Persist one live LLM event for gate verification |
| `smoke_db_flow.py` | E2E including `current-risk` + observability |

---

## 4. Runtime Provider Check

| Variable | Status |
|----------|--------|
| `OPENAI_API_KEY` | **SET** in `backend/.env.local` |
| `OPENAI_MODEL` | `gpt-4o-mini` |
| `OPENAI_RATE_LIMIT_PER_MINUTE` | `60` (default) |
| `OPENAI_MAX_TOKENS` | `120` (default) |

**DB observability (24h, after live seed):**

```
llm_success_count >= 1
fallback_rate < 100%
provider_configured: true
runtime_mode: live_llm
```

---

## 5. Observability Check

- `/api/observability/ai-summary` — **200** (admin token)
- `/api/observability/ai-summary-detailed` — **200**
- Provider metadata: `provider_configured`, `provider_name`, `runtime_mode`

---

## 6. Risk Engine vs Real AI

Unchanged: only `generate_explanation` is LLM; scoring/alerts/patterns are deterministic.

---

## 7. Mobile Integration

Dashboard `explanation` from `/api/air/current-risk`; Settings AI observability panel. `explanationSource` not shown in dashboard UI (P2).

---

## 8. Gaps

### P0

- **None locally** for LEVEL 4.

### P1 (LEVEL 5)

1. Run `--require-live` on **staging** after `OPENAI_API_KEY` GitHub secret is set.
2. Optional: CI job with real key (currently `--skip-if-unconfigured`).
3. Mobile LLM vs template badge.

### P2

1. `personal_pattern_v1` LLM (spec only).
2. Full observability charts in mobile.

---

## 9. Fixes Applied

| File | Change |
|------|--------|
| `ai_explanation_service.py` | Rate limit, timeout/max_tokens from settings |
| `settings.py` | `OPENAI_RATE_LIMIT_*`, `OPENAI_MAX_TOKENS`, loads `.env.local` |
| `check_ai_connection.py` | `--skip-if-unconfigured` |
| `seed_ai_live_probe.py` | Live DB event seeder |
| `smoke_db_flow.py` | AI endpoints in smoke |
| `run_backend_gate.py` | AI check in gate; `--require-ai-live` |
| `check_env_security.py` | WARN if staging lacks OpenAI key |
| `backend-deploy-staging.yml` | `OPENAI_*` secrets |
| `.env.example`, `.env.staging.example` | AI control vars |
| Tests | Rate limit fallback test |

---

## 10. Verification Results

```bash
python3 -m compileall backend/app backend/scripts -q          # exit 0
cd backend && .venv/bin/python -m pytest tests -q             # exit 0
.venv/bin/python scripts/check_ai_connection.py               # exit 0
.venv/bin/python scripts/check_ai_connection.py --require-live  # exit 0
.venv/bin/python scripts/run_backend_gate.py --skip-smoke --skip-db  # includes AI skip-if-unconfigured
python scripts/smoke_db_flow.py  # with local Postgres + CI env — includes current-risk + ai-summary
```

---

## 11. Owner Actions Required

1. ~~**GitHub staging secrets**~~ **Done (2026-06-04)**
2. ~~**GitHub production secrets**~~ **Done (2026-06-04)** — environment `production` created
3. **Trigger deploy** (staging/production workflow_dispatch) to validate remote in-smoke LLM path
4. **Never** commit keys to `.env.example`

---

## 12. Final Go/No-Go

| Gate | Verdict |
|------|---------|
| **AI MODULE ENGINEERING** | **GO** |
| **LIVE AI PROVIDER (local)** | **GO** |
| **PRODUCTION AI READINESS** | **CONDITIONAL GO** — staging/production secrets wired; pending first deploy workflow run |

**Classification:** **LEVEL 4**  
**LEVEL 5 criteria:** staging `--require-live`, optional CI with key, ops runbook — **partially delivered** (gate scripts + smoke + rate limits)
