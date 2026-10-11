# Текущее состояние доставки HiAir

Единая интеграция 11 октября 2026 собирает актуальный main, работающий API c3730d98, Action PR 75, auth PR 56, launch PR 57 и локальные Android parity изменения. Очередь и статусы находятся в DELIVERY_REGISTRY.json. Последний продуктовый план — roadmap amendment от 23 сентября с дополнениями октября; deferred voice, benchmark/ensemble/bias research не входят в этот релиз.

Рабочие каталоги: HIAir-main — постоянный чистый main; HIAir-integration — текущий кандидат. HIAir — сохранённый legacy checkout и общий Git storage. Старые worktrees перемещаются в .hiair-archive с сохранением ignored artifacts. Полные snapshots и all-refs bundle находятся вне git, в приватном архиве от 11 октября.

Релизный поезд: iOS 1.2 build 300; Android 1.2.0 code 300. Наличие сборки не означает public store release. Source SHA, merged SHA, deployed SHA и store processing фиксируются отдельно в итоговом release manifest.

Проверки текущего кандидата: iOS 230 unit tests PASS; Android 120 unit tests PASS и signed AAB собран; backend suite PASS с покрытием 76.31%; pip-audit PASS. Эти числа описывают запуски кандидата; последующие изменения требуют соответствующих свежих проверок. Сквозные critical-path device/IAP проверки и store approval остаются самостоятельными условиями.

Production security: account_deletion_operations и account_deletion_stage_events защищены RLS; клиентские grants отозваны, серверный доступ сохранён и перепроверен. Не переносить старый production pin документ как разрешение на feature deploy. Новый production deploy разрешён только по immutable SHA main после gates.
