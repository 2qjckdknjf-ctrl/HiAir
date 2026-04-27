# Инженерные гейты перед real-device QA

Выполни **локально** (Postgres + `.env.local` по `backend/.env.local.example`) перед `docs/qa/HIAIR-RC1-REAL-DEVICE-QA-PACKET.md`.

## Backend

```bash
cd backend
../.venv/bin/python -m pytest -q
PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
```

API + preflight (второй терминал или после smoke):

```bash
cd backend
set -a && source .env.local && set +a
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

```bash
cd backend
set -a && source .env.local && set +a
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

Один оркестратор: подхватывает **`.env.local`** (если есть) через `python-dotenv` перед шагами, чтобы `smoke_db_flow` и др. видели `DATABASE_URL` / webhook secret. HTTP preflight только с `--base-url`.

```bash
cd backend
../.venv/bin/python scripts/run_backend_gate.py

../.venv/bin/python scripts/run_backend_gate.py --base-url http://127.0.0.1:8000
```

## Mobile

```bash
cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

```bash
cd mobile/android && ./gradlew clean assembleDebug assembleRelease bundleRelease lint
```

## Манифест артефактов

```bash
python3 mobile/scripts/generate_release_manifest.py --rc
```
