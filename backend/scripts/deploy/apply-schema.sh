#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

profile="$(resolve_profile "${1:-development}")"
env_file="$(resolve_env_file "$profile")"

"$DEPLOY_SCRIPT_DIR/check-env.sh" "$profile" "$env_file"
load_env_file "$env_file"

build_args=()
if [ "$(env_value FF_COMPOSE_ALLOW_BUILD)" = "true" ]; then
  build_args+=(--build)
fi

info "starting backing services for $profile"
compose_cmd "$env_file" up -d postgres redis nats

info "starting application services so current idempotent schema initialization runs"
compose_cmd "$env_file" up -d "${build_args[@]}" \
  identity-service player-service economy-service production-service research-service \
  market-service social-chat-service world-service admin-service notification-service \
  gateway-service combat-service scheduler-service

info "schema initialization is currently service-startup based; replace this script with a dedicated migrator when formal migrations are introduced"
"$DEPLOY_SCRIPT_DIR/healthcheck.sh" "$profile"
