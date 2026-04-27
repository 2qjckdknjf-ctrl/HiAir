## Learned User Preferences
- User prefers autonomous execution with minimal back-and-forth and asks the agent to continue until major tasks are complete.
- User often prefers Russian for task instructions and progress communication.
- User values direct, action-oriented progress over extended planning-only responses.
- For HiAir readiness and audit work, user prefers evidence-first findings with file paths, concrete blockers, command/log/artifact proof before any GO verdict, and status vocabulary such as DONE, PARTIAL, MISSING, BLOCKED, RISK, and CRITICAL.
- User prefers hard step-by-step execution plans where each completed step is audited, verified, and immediately followed by fixes for any newly found gaps.

## Learned Workspace Facts
- Main project workspace is `/Users/alex/Projects/HIAir`.
- The workspace includes a FastAPI backend and native iOS/Android clients for a heat and air-quality wellness assistant.
- The team uses incremental continual-learning memory updates with transcript files under the Cursor project transcript store.
- HiAir Closed Beta/readiness work is tracked against canonical docs such as `docs/mvp-spec.md`, `docs/task-backlog.md`, `docs/roadmap-from-pdf.md`, and audit/readiness docs under `docs/`.
- HiAir multilingual support spans backend localization services plus native iOS `AppSession` strings and Android `AndroidL10n` dictionaries.
- HiAir Closed Beta RC work spans backend Postgres/API gates, iOS simulator and Android build gates, push-readiness docs under `docs/notifications/`, and release/owner action docs under `docs/release/`.
