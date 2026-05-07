#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

profile="$(resolve_profile "${1:-development}")"
env_file="$(resolve_env_file "$profile")"

"$DEPLOY_SCRIPT_DIR/check-env.sh" "$profile" "$env_file"
load_env_file "$env_file"
require_command curl
require_command jq

"$DEPLOY_SCRIPT_DIR/healthcheck.sh" "$profile"

gateway_base="$(env_value FF_GATEWAY_PUBLIC_BASE_URL)"
if [ -z "$gateway_base" ]; then
  gateway_base="http://127.0.0.1:$(env_value GATEWAY_PORT)"
fi

info "checking gateway health at $gateway_base"
curl -fsS "$gateway_base/health" >/dev/null
curl -fsS "$gateway_base/metadata" | jq -e '.service == "gateway-service"' >/dev/null

email="$(env_value FF_SMOKE_EMAIL)"
password="$(env_value FF_SMOKE_PASSWORD)"
if [ -z "$email" ] || [ -z "$password" ]; then
  info "FF_SMOKE_EMAIL/FF_SMOKE_PASSWORD not set; unauthenticated smoke checks passed"
  exit 0
fi

info "running authenticated gateway smoke checks"
auth_response="$(curl -fsS -X POST "$gateway_base/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$email\",\"password\":\"$password\"}")"
token="$(jq -r '.token // empty' <<< "$auth_response")"
player_id="$(jq -r '.user.uid // empty' <<< "$auth_response")"
[ -n "$token" ] || die "auth smoke login did not return a token"
[ -n "$player_id" ] || die "auth smoke login did not return a player id"

auth_header="Authorization: Bearer $token"
curl -fsS "$gateway_base/auth/me" -H "$auth_header" | jq -e '.player.uid == "'"$player_id"'" or .user.uid == "'"$player_id"'"' >/dev/null
curl -fsS "$gateway_base/world/countries" -H "$auth_header" | jq -e '.countries | length >= 1' >/dev/null
curl -fsS "$gateway_base/world/battles?status=current" -H "$auth_header" | jq -e 'has("battles")' >/dev/null
curl -fsS "$gateway_base/players/$player_id/state" -H "$auth_header" | jq -e '.playerId == "'"$player_id"'"' >/dev/null

info "$profile smoke checks passed"
