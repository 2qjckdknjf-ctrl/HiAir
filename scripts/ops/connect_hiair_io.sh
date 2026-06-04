#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WEB_DIR="${ROOT_DIR}/web"
DOMAIN="${HIAIR_DOMAIN:-hiair.io}"
API_HOST="${HIAIR_API_HOST:-api.hiair.io}"
CF_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
CF_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
PAGES_PROJECT="${CLOUDFLARE_PAGES_PROJECT:-hiair-web}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  deploy-all     Deploy web (${DOMAIN}) + API (${API_HOST}) on Cloudflare
  deploy-web     Deploy Pages site + Worker proxy (uses wrangler login)
  deploy-api     Deploy FastAPI container to ${API_HOST}
  deploy-web-token  Same as deploy-web but requires CLOUDFLARE_API_TOKEN + ACCOUNT_ID
  dns-records    Print recommended DNS records for ${DOMAIN}
  dns-apply      Apply apex + www CNAME records via Cloudflare API (requires token + zone)
  verify         Check DNS and HTTP endpoints for ${DOMAIN} and ${API_HOST}

Environment:
  CLOUDFLARE_API_TOKEN   Cloudflare API token (Pages + DNS edit)
  CLOUDFLARE_ACCOUNT_ID  Cloudflare account id (for Pages deploy)
  CLOUDFLARE_ZONE_ID     Optional; auto-detected for ${DOMAIN} if unset
  HIAIR_DOMAIN           Default: hiair.io
  HIAIR_API_HOST         Default: api.hiair.io
EOF
}

require_token() {
  if [[ -z "${CF_API_TOKEN}" ]]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN is required." >&2
    exit 1
  fi
}

cf_api() {
  local method="$1"
  local path="$2"
  shift 2
  curl -fsS -X "${method}" \
    "https://api.cloudflare.com/client/v4${path}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

resolve_zone_id() {
  if [[ -n "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    echo "${CLOUDFLARE_ZONE_ID}"
    return
  fi
  cf_api GET "/zones?name=${DOMAIN}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["result"][0]["id"])'
}

deploy-web() {
  echo "[pages] deploying ${WEB_DIR} -> project ${PAGES_PROJECT}"
  (
    cd "${WEB_DIR}"
    npx --yes wrangler@4 pages deploy . \
      --project-name="${PAGES_PROJECT}" \
      --branch=production \
      --commit-dirty=true
  )
  echo "[worker] deploying edge proxy for ${DOMAIN} and www.${DOMAIN}"
  (
    cd "${ROOT_DIR}/infra/cloudflare/hiair-io-proxy"
    npx --yes wrangler@4 deploy
  )
  echo "[done] site should be live at https://${DOMAIN}/ once DNS/SSL propagate (1-5 min)"
}

deploy-web-token() {
  require_token
  if [[ -z "${CF_ACCOUNT_ID}" ]]; then
    echo "ERROR: CLOUDFLARE_ACCOUNT_ID is required for Pages deploy." >&2
    exit 1
  fi
  deploy-web
}

deploy-api() {
  "${ROOT_DIR}/scripts/ops/deploy_hiair_api_cloudflare.sh"
}

deploy-all() {
  deploy-web
  deploy-api
}

print_dns_records() {
  cat <<EOF
DNS for ${DOMAIN} (Cloudflare zone):

Marketing site:
  ${DOMAIN}       Worker -> ${PAGES_PROJECT}.pages.dev
  www.${DOMAIN}   Worker -> ${PAGES_PROJECT}.pages.dev

Backend API:
  ${API_HOST}     Worker custom domain (Cloudflare Containers)

Deploy everything:
  ./scripts/ops/connect_hiair_io.sh deploy-all

Supabase Auth (Dashboard -> Auth -> URL configuration):
  Site URL: https://${DOMAIN}
  Redirect URLs (keep existing mobile deep links):
    hiair://auth/callback

Mobile / backend production URLs:
  API_BASE_URL=https://${API_HOST}
  LEGAL_PRIVACY_POLICY_URL=https://${DOMAIN}/privacy/
  LEGAL_TERMS_URL=https://${DOMAIN}/terms/
EOF
}

dns_apply() {
  require_token
  local zone_id
  zone_id="$(resolve_zone_id)"
  local pages_target="${PAGES_PROJECT}.pages.dev"

  upsert_record() {
    local name="$1"
    local content="$2"
    local existing
    existing="$(cf_api GET "/zones/${zone_id}/dns_records?type=CNAME&name=${name}" \
      | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r[0]["id"] if r else "")')"
    local payload
    payload="$(python3 - <<PY
import json
print(json.dumps({
  "type": "CNAME",
  "name": "${name}",
  "content": "${content}",
  "proxied": True,
  "ttl": 1,
}))
PY
)"
    if [[ -n "${existing}" ]]; then
      echo "[dns] update ${name} -> ${content}"
      cf_api PUT "/zones/${zone_id}/dns_records/${existing}" --data "${payload}" >/dev/null
    else
      echo "[dns] create ${name} -> ${content}"
      cf_api POST "/zones/${zone_id}/dns_records" --data "${payload}" >/dev/null
    fi
  }

  upsert_record "${DOMAIN}" "${pages_target}"
  upsert_record "www.${DOMAIN}" "${pages_target}"
  echo "[dns] Pages CNAME records applied when using API token. ${API_HOST} is provisioned by wrangler deploy."
}

verify_endpoints() {
  echo "== DNS =="
  dig +short "${DOMAIN}" A CNAME 2>/dev/null || true
  dig +short "www.${DOMAIN}" A CNAME 2>/dev/null || true
  dig +short "${API_HOST}" A CNAME 2>/dev/null || true
  echo
  echo "== HTTP =="
  for url in "https://${DOMAIN}/" "https://${DOMAIN}/privacy/" "https://${DOMAIN}/terms/" "https://${API_HOST}/api/health"; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${url}" 2>/dev/null || echo "000")"
    echo "${code}  ${url}"
  done
}

case "${1:-}" in
  deploy-all) deploy-all ;;
  deploy-web) deploy-web ;;
  deploy-api) deploy-api ;;
  deploy-web-token) deploy-web-token ;;
  dns-records) print_dns_records ;;
  dns-apply) dns_apply ;;
  verify) verify_endpoints ;;
  *)
    usage
    exit 1
    ;;
esac
