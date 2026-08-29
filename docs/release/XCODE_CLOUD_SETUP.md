# Xcode Cloud — HiAir TestFlight (Xcode 26)

Локальный Mac на Xcode 15.2 не проходит загрузку в ASC (нужен **iOS 26 SDK / Xcode 26**). Сборка и выгрузка в TestFlight — через **Xcode Cloud** в App Store Connect.

## Репозиторий

| Параметр | Значение |
|----------|----------|
| GitHub | `2qjckdknjf-ctrl/HiAir` |
| Ветка | `main` |
| Xcode project | `mobile/ios/HiAir.xcodeproj` |
| Scheme | `HiAir` |
| Bundle ID | `com.hiair.app` |
| Team ID | `43A4KW5BKB` |

Скрипты CI: `mobile/ios/ci_scripts/ci_post_clone.sh` (release gate + XcodeGen + SwiftPM).

**Incident (2026-08-29):** the live ASC workflow also started Archive on feature branches and PRs (`seo/search-foundation`, `feat/web-live-store-qr`, `docs/live-store-audit-followup`, `main`) and delivered binaries with `CFBundleShortVersionString = 1.0.1` against live store **1.1**. Policy: `docs/ios/XCODE_CLOUD_RELEASE_POLICY.md`. `ci_post_clone.sh` now refuses automatic Archive unless the start is Manual / `release/*` / tag `ios-*` (and marketing version > 1.1).

**Do not push to `main` expecting an App Store upload.** Web/SEO commits must never distribute.

## 1. Подключить репозиторий (один раз)

1. [App Store Connect](https://appstoreconnect.apple.com) → приложение **HiAir**
2. Вкладка **Xcode Cloud** (или **Settings → Xcode Cloud**)
3. **Get Started** / **Create Workflow**
4. Выбрать **GitHub** → авторизовать Apple ↔ GitHub
5. Репозиторий: **2qjckdknjf-ctrl/HiAir**
6. Убедиться, что на `main` есть коммит с `mobile/ios/ci_scripts/`

## 2. Создать workflow

| Поле | Значение |
|------|----------|
| Name | `HiAir TestFlight` |
| Product | HiAir (`com.hiair.app`) |
| Project/Workspace | `mobile/ios/HiAir.xcodeproj` |
| Scheme | `HiAir` |
| Platform | iOS |
| Start condition (intended) | **Manual**, Tag `ios-*`, or Branch `release/*` — **not** Any Branch, **not** every PR |

**Actions (порядок):**

1. **Archive** — Release, generic iOS device  
2. **TestFlight Internal Testing** — включить автоматическую доставку (опционально: External после ручного шага)

**Post-actions:**

- **TestFlight** — Internal testers / группа по умолчанию

Подпись: **Automatically manage signing** (team `43A4KW5BKB`). При первом запуске Xcode Cloud запросит доступ к сертификатам в Apple Developer — подтвердить.

## 3. Environment (если понадобится позже)

Для чистой сборки store-конфига достаточно **Release** в `project.yml` (`INFOPLIST_KEY_API_BASE_URL` = `https://api.hiair.io`). Секреты OpenAI/backend в Xcode Cloud для Archive **не нужны**.

## 4. Запуск

Ordinary iOS compile/test: GitHub Actions **iOS CI** (path-filtered). It does not upload.

App Store Connect upload: Xcode Cloud → **Start Build** (Manual), or an `ios-*` tag / `release/*` branch **after** `MARKETING_VERSION` is greater than live **1.1**. See `docs/ios/XCODE_CLOUD_RELEASE_POLICY.md`.

После успешного Archive сборка появится в **TestFlight** (обработка Apple 5–30 мин). Do not auto-submit to the production App Store.

## 5. Локальная загрузка (если есть Xcode 26)

```bash
bash mobile/ios/scripts/archive_and_upload_testflight.sh
bash mobile/ios/scripts/upload_ipa_testflight_api.sh
```

Требует `backend/.secrets/apple_issuer_id` и `AuthKey_VCL6R84SP3.p8`.

## Troubleshooting

| Симптом | Действие |
|---------|----------|
| Scheme not found | Проверить `ci_post_clone.sh` в логе; `xcodegen generate` должен пройти |
| SDK / upload rejected locally | Только Xcode Cloud или Xcode 26+ |
| Signing failed | ASC → Xcode Cloud → Manage Certificates; Developer portal App ID `com.hiair.app` |
| `Cannot find HiAirV2Theme in scope` | Workflow собрал **старый коммит** без файлов в `project.pbxproj`; перезапусти build с **`main`** (после `ci_post_clone` fix) |
| SPM resolve failed | Лог `resolvePackageDependencies`; сеть к github.com/supabase |

## Ссылки

- [Writing custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [SDK minimum requirements (iOS 26)](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)
