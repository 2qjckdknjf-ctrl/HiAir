# HiAir experiment instrumentation baseline

**Generated:** 2026-08-31  
**Production deploy this slice:** NO  
**Experiment flag:** `HIAIR_EXPERIMENTS_ENABLED=false`

## Production website source-of-truth

GitHub default branch `cursor/bootstrap-ci-and-tooling` is **not** the marketing site source.

| Fact | Value |
| --- | --- |
| Live origin | `https://hiair.io` (Cloudflare; `cf-ray`, `server: cloudflare`) |
| Deploy workflow | `.github/workflows/hiair-io-pages.yml` |
| Trigger | push to **`main`** paths `web/**`, `infra/cloudflare/**` |
| Pages project | `hiair-web` (`wrangler pages deploy . --project-name=hiair-web --branch=production`) |
| Domain proxy | Worker `infra/cloudflare/hiair-io-proxy` |
| Website path in repo | `web/` |
| Last successful Pages run | `33268279755` (2026-08-29T18:26:45Z) head `8d5f17bf3f97b370c3b64e5f3e5f88a27a48918d` |
| Last `main` commit touching `web/` | `1e233658ad4c6ed147193be6798cb3b90e7d96eb` (`seo: search foundation for hiair.io`) |
| `origin/main` at audit | `9aa2114cbc1456799c4bcc1b55fa42d328914ce2` (later CI-only commits; `web/` tree unchanged) |

### Live vs `origin/main` `web/`

| Asset | Result |
| --- | --- |
| `https://hiair.io/` HTML SHA-256 | **exact match** `origin/main:web/index.html` |
| `https://hiair.io/js/main.js` | **exact match** after deploy inject of `GROWTH_OS_EVENTS_URL` → `https://growth-os-sable-psi.vercel.app/api/v1/events` |
| Header CTA copy | `Download on the App Store` |

Provenance is **proven**. Instrumentation may land on a branch from `main`. It must not merge or deploy in Slice 04.

## Local workspace (do not use for this slice)

`/Users/alex/Projects/HiAir` was on dirty `design/redesign-v4-deep-glass`. Slice 04 uses a clean worktree from `origin/main`:

`/Users/alex/Projects/HiAir-slice04`

## Open PRs (not website production)

Several PRs still target `cursor/bootstrap-ci-and-tooling`. Website PRs that matter historically targeted `main` (e.g. Deep Glass redesign #47, live store CTAs). This slice’s HiAir PR must target **`main`**.
