# HiAir

HiAir - мобильный wellness-ассистент по жаре и качеству воздуха.

Проект заново стартован с документации на основе файла
`Идеи для вирусных приложений.pdf`.

## Базовые документы

- `docs/roadmap-from-pdf.md` - полный roadmap по фазам 1-6.
- `docs/mvp-spec.md` - четкие рамки MVP.
- `docs/architecture.md` - архитектура и модель данных MVP.
- `docs/task-backlog.md` - пошаговый план исполнения.
- `docs/risk-thresholds-v1.md` - пороги risk engine v1.
- `docs/beta-readiness-checklist.md` - чеклист подготовки закрытой беты.
- `docs/qa-checklist.md` - QA-чеклист пользовательских сценариев.
- `docs/beta-execution-runbook.md` - пошаговый operational runbook беты.
- `docs/release-notes-template.md` - шаблон release notes для beta-сборок.
- `docs/bug-report-template.md` - шаблон bug report для triage.
- `docs/beta-cycle-001-report.md` - отчет первого beta preflight прогона.
- `docs/beta-cycle-002-report.md` - отчет полного backend+mobile beta цикла.
- `docs/mobile-beta-build-commands.md` - команды и шаги mobile beta сборок.
- `docs/qa-run-001-report.md` - результат технического QA-прогона перед загрузкой.
- `docs/qa-run-002-report.md` - QA по security/subscription hardening.
- `docs/qa-run-003-report.md` - QA по CI hardening.
- `docs/qa-run-004-report.md` - QA по backend gate и свежим mobile build.
- `docs/qa-run-005-report.md` - QA по automation manifest артефактов.
- `docs/mobile-audit-2026-04-07.md` - полный аудит mobile и исправления.
- `docs/store-upload-last-mile.md` - минимальные шаги финальной загрузки в сторы.
- `docs/release-artifacts-manifest.md` - SHA256/размеры текущих релизных артефактов.
- `docs/release-package-2026-04-07.md` - готовый пакет передачи на ручной store upload.
- `docs/ops-retention-runbook.md` - запуск/расписание retention cleanup.
- `docs/ops-handover-checklist.md` - чеклист передачи в эксплуатацию.
- `docs/data-retention-matrix.md` - матрица покрытия retention/delete по таблицам.
- `docs/incident-response-runbook.md` - минимальный incident process для beta.
- `docs/next-agent-handoff.md` - handoff для следующего разработчика/агента.
- `docs/privacy-policy-draft.md` - черновик Privacy Policy.
- `docs/terms-of-service-draft.md` - черновик Terms of Service.
- `docs/api-contract-risk-levels.md` - договоренность по risk-level alias и deprecation.
- `docs/store-metadata-packet.md` - единый пакет store metadata/privacy label.

## С чего начинаем сейчас

1. Поддерживаем truth-alignment между docs и фактическим кодом.
2. Закрываем critical/high gaps из `docs/_operator/master-gap-report.md`.
3. Ведем фазное доведение до Closed Beta / Store handoff readiness.
