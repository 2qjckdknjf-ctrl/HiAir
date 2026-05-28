## Learned User Preferences
- User prefers autonomous execution with minimal back-and-forth; for large work, audit then plan then implement in phases without mid-task confirmation unless blocked, and continue until major tasks are complete.
- User often prefers Russian for task instructions and progress communication.
- User values direct, action-oriented progress over extended planning-only responses.
- User frequently asks for deep end-to-end audits and full hardening/closure rather than partial fixes.
- User prioritizes high-quality, polished outcomes and is comfortable trading speed for quality.
- User expects Supabase project provisioning, migrations, and server-side secrets to be handled via Supabase MCP/server automation rather than manual dashboard or local PAT flows when possible.
- For brand or visual redesign work, keep scope to design tokens, components, and assets only; integrate supplied mockups or publish packs for orb, icons, and launch assets without changing backend, API, auth, data models, risk engine, or business flows, and keep UI components presentation-only.

## Learned Workspace Facts
- Main project workspace is `/Users/alex/Projects/HIAir`.
- The workspace includes a mobile app effort (iOS and Android) plus backend/services work under the HiAir project.
- The team uses incremental continual-learning memory updates with transcript files under the Cursor project transcript store.
- The product scope includes multilingual UX/content support across Russian, English, Spanish, Italian, and French.
- GitHub repository is `2qjckdknjf-ctrl/HiAir`; for pushes with large binary assets, prefer the `hiair` remote or SSH (`git@github.com:2qjckdknjf-ctrl/HiAir.git`) when HTTPS push fails.
- Backend is Python/FastAPI under `backend/` (risk engine, ingestion, notifications, privacy orchestration); production data/auth use Supabase PostgreSQL with RLS and Supabase Auth, with schema migrations in `backend/sql/`.
- Production Supabase project is named `hiair-prod` (region `eu-central-1`); operator docs for Supabase/auth live under `docs/_operator/`.
- Release closure is validated with `scripts/release/hiair_final_gate.sh` (including `--strict-external` for owner/legal readiness).
- Brand source of truth is under `docs/brand/` (HiAir Orb / Aurora Calm; UI and store copy spell **HiAir**; tagline **Breathe better. Live better.**); iOS tokens/components live under `mobile/ios/HiAir/DesignSystem/`, Android under `mobile/android/app/src/main/java/com/hiair/ui/design/`, and store graphics under `docs/brand/store-assets/`.
- Mobile brand PNGs: iOS in-app orb uses `.renderingMode(.original)`; AppIcon must be a full opaque `AppIcon.appiconset`; Android launcher uses `@mipmap/ic_launcher` adaptive icons and `imageTintList = null` on orb `ImageView`s so logos are not template-tinted.
