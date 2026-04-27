# Android — локальное подключение FCM (опционально)

Цель: получить реальный FCM token на устройстве и записать его в `SharedPreferences` `hiair_push` / ключ `fcm_token`, чтобы `PushTokenRegistrar` мог вызвать `POST /api/notifications/device-token`.

**Не коммить:** `mobile/android/app/google-services.json` (уже в `.gitignore`).

## Репозиторий уже поддерживает FCM «по флажку»

Когда **`mobile/android/app/google-services.json` существует локально**, Gradle автоматически:

- выставляет `BuildConfig.FIREBASE_CONFIGURED = true`;
- подключает `com.google.gms.google-services`, Firebase BOM и `firebase-messaging-ktx`;
- компилирует `src/firebase/java/com/hiair/FcmFirebaseBootstrap.kt`, который кэширует FCM token в prefs.

`PushTokenRegistrar` перед аплоадом вызывает `FcmTokenRefresher` → bootstrap. Без JSON всё отключается, сборки остаются зелёными.

## 1. Firebase Console

1. Создай приложение Android с package `com.hiair`.
2. Скачай `google-services.json` в **`mobile/android/app/google-services.json`** (только локально).

## 2. Пересборка

```bash
cd mobile/android
./gradlew :app:assembleDebug
```

Gradle подхватит JSON и включит Firebase. Если JSON удалили — снова «лёгкий» билд без FCM.

## 3. Ротация FCM token (`onNewToken`)

В репозитории уже есть **`HiAirFirebaseMessagingService`** (`src/firebase/java/...`) — он пишет новый токен в `hiair_push` / `fcm_token`.

Регистрация сервиса в манифесте **автоматическая**: при наличии `google-services.json` Gradle подмешивает `src/firebase/AndroidManifest.xml` (`manifest.srcFile` в `app/build.gradle.kts`), вместе с исходниками `src/firebase/java`.

Без JSON этот фрагмент не подключается; токен по-прежнему можно получить через `FcmFirebaseBootstrap.refresh` при логине / `PushTokenRegistrar`.

## 4. Проверка

1. `./gradlew :app:assembleDebug`
2. Logcat: `HiAirPush` — `FCM token cached locally`, затем `token upload attempted` → `token registered` при залогиненной сессии.
