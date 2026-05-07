#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

profile="$(resolve_profile "${1:-development}")"
env_file="$(resolve_env_file "$profile")"

load_env_file "$env_file"
require_command docker
require_command jq

info "checking compose health for $profile"
ps_json="$(compose_cmd "$env_file" ps --format json)"
services=(
  postgres
  redis
  nats
  identity-service
  player-service
  economy-service
  production-service
  research-service
  market-service
  social-chat-service
  world-service
  admin-service
  notification-service
  gateway-service
  combat-service
)

failed=0
for service in "${services[@]}"; do
  row="$(jq -cs --arg service "$service" '.[] | select(.Service == $service)' <<< "$ps_json")"
  if [ -z "$row" ]; then
    echo "missing: $service"
    failed=1
    continue
  fi
  state="$(jq -r '.State // ""' <<< "$row")"
  health="$(jq -r '.Health // ""' <<< "$row")"
  if [ "$state" != "running" ]; then
    echo "not running: $service state=$state health=$health"
    failed=1
  elif [ -n "$health" ] && [ "$health" != "healthy" ]; then
    echo "unhealthy: $service state=$state health=$health"
    failed=1
  else
    echo "ok: $service"
  fi
done

[ "$failed" -eq 0 ] || die "one or more services are not healthy"
info "$profile compose services are healthy"
