## Learned User Preferences
- User prefers autonomous execution with minimal back-and-forth and asks the agent to continue until major tasks are complete.
- User often prefers Russian for task instructions and progress communication.
- User values direct, action-oriented progress over extended planning-only responses.
- User frequently asks for deep end-to-end audits and full hardening/closure rather than partial fixes.
- User prioritizes high-quality, polished outcomes and is comfortable trading speed for quality.
- User expects Supabase project provisioning, migrations, and server-side secrets to be handled via Supabase MCP/server automation rather than manual dashboard or local PAT flows when possible.

## Learned Workspace Facts
- Main project workspace is `/Users/alex/Projects/HIAir`.
- The workspace includes a mobile app effort (iOS and Android) plus backend/services work under the HiAir project.
- The team uses incremental continual-learning memory updates with transcript files under the Cursor project transcript store.
- The product scope includes multilingual UX/content support across Russian, English, Spanish, Italian, and French.
- GitHub repository is `2qjckdknjf-ctrl/HiAir`.
- Backend is Python/FastAPI under `backend/`, with Postgres schema migrations in `backend/sql/` and Supabase-first auth configuration.
- Production Supabase project is named `hiair-prod` (region `eu-central-1`); operator docs for Supabase/auth live under `docs/_operator/`.
- Release closure is validated with `scripts/release/hiair_final_gate.sh` (including `--strict-external` for owner/legal readiness).
