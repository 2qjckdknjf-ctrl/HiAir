#!/usr/bin/env bash
# Add mobile OAuth redirect URLs to hiair-prod Supabase Auth (Management API).
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-qhxesaemlhzwbunpqjoo}"
CREDS="${SUPABASE_CREDENTIALS_FILE:-$HOME/.config/hiair/supabase-credentials.env}"

if [[ -f "$CREDS" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$CREDS" && set +a
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "error: set SUPABASE_ACCESS_TOKEN in $CREDS (see docs/_operator/supabase-env-setup.md)" >&2
  exit 1
fi

REDIRECTS=(
  "hiair://auth/callback"
  "https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback"
)

payload="$(python3 - <<'PY'
import json, os
redirects = [
    "hiair://auth/callback",
    "https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback",
]
print(json.dumps({"uri_allow_list": redirects}))
PY
)"

echo "==> PATCH auth redirect URLs on $PROJECT_REF"
curl -fsS -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('uri_allow_list', d.get('uri_allow_list'))"

echo "Done. Enable Apple/Google providers in Dashboard → Authentication → Providers."
