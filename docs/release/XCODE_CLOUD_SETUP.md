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

Скрипты CI: `mobile/ios/ci_scripts/ci_post_clone.sh` (XcodeGen + SwiftPM).

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
| Start condition | Branch Changes → `main` (и при необходимости теги/release) |

**Actions (порядок):**

1. **Archive** — Release, generic iOS device  
2. **TestFlight Internal Testing** — включить автоматическую доставку (опционально: External после ручного шага)

**Post-actions:**

- **TestFlight** — Internal testers / группа по умолчанию

Подпись: **Automatically manage signing** (team `43A4KW5BKB`). При первом запуске Xcode Cloud запросит доступ к сертификатам в Apple Developer — подтвердить.

## 3. Environment (если понадобится позже)

Для чистой сборки store-конфига достаточно **Release** в `project.yml` (`INFOPLIST_KEY_API_BASE_URL` = `https://api.hiair.io`). Секреты OpenAI/backend в Xcode Cloud для Archive **не нужны**.

## 4. Запуск

- Push в `main` с изменениями под `mobile/ios/**`, или  
- Xcode Cloud → workflow → **Start Build**

После успешного Archive сборка появится в **TestFlight** (обработка Apple 5–30 мин).

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
| SPM resolve failed | Лог `resolvePackageDependencies`; сеть к github.com/supabase |

## Ссылки

- [Writing custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [SDK minimum requirements (iOS 26)](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)
