# HiAir AI Live Connection Audit

**Audit date:** 2026-06-04 (closure)  
**Branch:** `main` @ `7416107`  
**Auditor mode:** truth-based repo + runtime probes (no secrets exposed)

---

## 1. Executive Verdict

| Item | Result |
|------|--------|
| **AI status** | Live LLM connected locally and on **GitHub staging gate** |
| **Classification level** | **LEVEL 5 — Production-ready AI ops path** |
| **Is OpenAI/LLM live connected** | **YES** — staging deploy `--require-live` **exit 0** |
| **Is fallback active** | **Degraded mode only** — template fallback when key missing or guardrails block |
| **Is deterministic risk engine active** | **YES** |
| **Remaining infra gap** | `HIAIR_DEPLOY_COMMAND` unset — backend host push is **verification-only** until a PaaS/VM command is supplied |

### Authoritative gates

| Check | Local | Staging CI (run `26935252617`) |
|-------|-------|--------------------------------|
| `OPENAI_API_KEY` configured | **SET** in `backend/.env.local` | **SET** (GitHub secret) |
| `DB smoke flow passed` | **PASS** (legacy local Postgres) | **PASS** (Supabase + Admin Auth) |
| `explanationSource=llm` in smoke | **PASS** when key set | **PASS** |
| `check_ai_connection.py --require-live` | **exit 0** | **exit 0** (`llm_success_count: 1`) |
| Supabase schema | migrations **001–011** on `hiair-prod` | init_db idempotent on remote |

---

## 2. Evidence Matrix

| Area | Evidence | Status |
|------|----------|--------|
| AI service + OpenAI HTTP | `ai_explanation_service.py` | **Present** |
| Rate limit / cost caps | `OPENAI_RATE_LIMIT_PER_MINUTE`, `OPENAI_MAX_TOKENS`, timeout | **Added** |
| Local env key | `backend/.env.local` | **SET** |
| DB live event | `ai_explanation_events.used_fallback=false` | **Recorded** |
| `--require-live` gate | `check_ai_connection.py --require-live` | **PASS (local + staging)** |
| Seed helper | `scripts/seed_ai_live_probe.py` | **Added** |
| Smoke covers AI | `smoke_db_flow.py` → Supabase Admin Auth + `/api/air/current-risk` | **Added** |
| Backend gate | `run_backend_gate.py` → init_db before AI check | **Fixed** |
| CI | `backend-ci.yml` — skip-if-unconfigured when no key | **Green path** |
| Staging deploy | GitHub secrets + workflow run `26935252617` | **PASS** |
| Production deploy | Secrets wired; workflow ready (`workflow_dispatch`) | **Ready** |
| Supabase | `hiair-prod` (`qhxesaemlhzwbunpqjoo`), migration **011** FK fixup | **Applied** |
| Deploy gate | `deploy_backend.sh` smoke LLM + seed/require-live | **PASS on staging** |
| Mobile AI UI | Dashboard + Settings observability | **Integrated** |

---

## 3. AI Module Map

LLM layer = `ai_explanation_service.py` only; risk/recommendations/correlation = deterministic.

**Scripts:**

| Script | Purpose |
|--------|---------|
| `check_ai_connection.py` | Env + DB observability; `--require-live`, `--skip-if-unconfigured` |
| `seed_ai_live_probe.py` | Persist one live LLM event for gate verification |
| `smoke_db_flow.py` | E2E including Supabase auth path + `current-risk` + observability |

---

## 4. Runtime Provider Check

| Variable | Status |
|----------|--------|
| `OPENAI_API_KEY` | **SET** locally + GitHub staging/production |
| `OPENAI_MODEL` | `gpt-4o-mini` |
| `OPENAI_RATE_LIMIT_PER_MINUTE` | `60` |
| `OPENAI_MAX_TOKENS` | `120` |
| `SUPABASE_URL` / keys | **SET** in GitHub staging/production |

**JWT verification:** `SUPABASE_JWT_SECRET` empty locally — JWKS used on CI/runners (acceptable).

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

Dashboard `explanation` from `/api/air/current-risk`; Settings AI observability panel. `explanationSource` badge in dashboard UI remains **P2**.

---

## 8. Gaps

### P0

- **None** for AI module closure.

### P1

1. **`HIAIR_DEPLOY_COMMAND`** — no hosting platform in repo; staging/production run **verification-only** migrate/smoke/AI gates until operator sets deploy command for `https://api.hiair.app` host.
2. Mobile LLM vs template badge (P2 UX).

### P2

1. `personal_pattern_v1` LLM (spec only).
2. Full observability charts in mobile.

---

## 9. Fixes Applied (full closure cycle)

| File | Change |
|------|--------|
| `ai_explanation_service.py` | Rate limit, timeout/max_tokens from settings |
| `settings.py` | AI control vars, loads `.env.local` |
| `check_ai_connection.py` | Early skip before DB when unconfigured |
| `run_backend_gate.py` | init_db before AI check |
| `smoke_db_flow.py` | Supabase Admin Auth smoke path |
| `profile_access.py` / repositories | `user_id` on Supabase profile-owned writes |
| `011_supabase_auth_user_fk_fixup.sql` | FK drift fix on `hiair-prod` |
| `backend-deploy-*.yml` | `OPENAI_*` + `SUPABASE_*` secrets |
| GitHub environments | staging + production secrets synced |

---

## 10. Verification Results

```bash
python3 -m compileall backend/app backend/scripts -q                    # exit 0
cd backend && .venv/bin/python -m pytest tests -q                       # exit 0
.venv/bin/python scripts/check_ai_connection.py --require-live            # exit 0 (local)
.venv/bin/python scripts/run_backend_gate.py --skip-smoke               # exit 0
# GitHub Actions: Backend Deploy Staging run 26935252617                  # PASS
#   DB smoke flow passed + --require-live GO (llm_success_count: 1)
```

---

## 11. Owner Actions Required

1. ~~GitHub staging/production secrets~~ **Done (2026-06-04)**
2. ~~Staging deploy validation~~ **Done** — run `26935252617`
3. **Optional:** set `HIAIR_DEPLOY_COMMAND` when backend host (Fly/Render/VM) is chosen
4. **Optional:** populate `SUPABASE_ACCESS_TOKEN` for `sync_supabase_secrets.py` JWT sync
5. **Never** commit keys to `.env.example`

---

## 12. Final Go/No-Go

| Gate | Verdict |
|------|---------|
| **AI MODULE ENGINEERING** | **GO** |
| **LIVE AI PROVIDER (local)** | **GO** |
| **LIVE AI PROVIDER (staging gate)** | **GO** |
| **PRODUCTION AI READINESS** | **GO** for verification gate; **CONDITIONAL** for live API host until `HIAIR_DEPLOY_COMMAND` |

**Classification:** **LEVEL 5**  
**Criteria met:** staging `--require-live`, Supabase remote smoke, secrets automation, rate limits, observability gates, CI gate ordering fix.
