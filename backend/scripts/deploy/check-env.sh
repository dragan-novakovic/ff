#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

profile="$(resolve_profile "${1:-development}")"
env_file="$(resolve_env_file "$profile" "${2:-}")"

load_env_file "$env_file"

info "validating $profile deployment environment from $env_file"

required=(
  FF_DEPLOY_ENV
  FF_COMPOSE_PROJECT_NAME
  FF_CONTAINER_PREFIX
  FF_IMAGE_TAG
  FF_PORT_BIND_ADDRESS
  ASPNETCORE_ENVIRONMENT
  DOTNET_ENVIRONMENT
  FF_DB_INCLUDE_ERROR_DETAIL
  FF_COMPOSE_ALLOW_BUILD
  POSTGRES_HOST
  POSTGRES_PORT
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  FF_IDENTITY_TOKEN_SECRET
  FF_INTERNAL_SERVICE_TOKEN
)

if [ "$profile" != "development" ]; then
  required+=(FF_ADMIN_TOKEN GRAFANA_ADMIN_PASSWORD)
fi

missing=()
for key in "${required[@]}"; do
  if [ -z "$(env_value "$key")" ]; then
    missing+=("$key")
  fi
done
[ "${#missing[@]}" -eq 0 ] || die "missing required variables: ${missing[*]}"

case "$profile" in
  development)
    [ "$(env_value ASPNETCORE_ENVIRONMENT)" = "Development" ] ||
      die "ASPNETCORE_ENVIRONMENT must be Development for development"
    ;;
  staging)
    [ "$(env_value ASPNETCORE_ENVIRONMENT)" = "Staging" ] ||
      die "ASPNETCORE_ENVIRONMENT must be Staging for staging"
    ;;
  production)
    [ "$(env_value ASPNETCORE_ENVIRONMENT)" = "Production" ] ||
      die "ASPNETCORE_ENVIRONMENT must be Production for production"
    ;;
esac

if [ "$profile" != "development" ]; then
  [ "$(env_value DOTNET_ENVIRONMENT)" = "$(env_value ASPNETCORE_ENVIRONMENT)" ] ||
    die "DOTNET_ENVIRONMENT must match ASPNETCORE_ENVIRONMENT"
  [ "$(env_value FF_DB_INCLUDE_ERROR_DETAIL)" = "false" ] ||
    die "FF_DB_INCLUDE_ERROR_DETAIL must be false outside development"
  [ "$(env_value FF_COMPOSE_ALLOW_BUILD)" = "false" ] ||
    die "FF_COMPOSE_ALLOW_BUILD must be false outside development"
  [ -z "$(env_value FF_IDENTITY_SEED_EMAIL)" ] ||
    die "FF_IDENTITY_SEED_EMAIL must be empty outside development"
  [ -z "$(env_value FF_IDENTITY_SEED_PASSWORD)" ] ||
    die "FF_IDENTITY_SEED_PASSWORD must be empty outside development"

  sensitive=(
    POSTGRES_PASSWORD
    FF_IDENTITY_TOKEN_SECRET
    FF_INTERNAL_SERVICE_TOKEN
    FF_ADMIN_TOKEN
    GRAFANA_ADMIN_PASSWORD
  )
  for key in "${sensitive[@]}"; do
    value="$(env_value "$key")"
    case "$value" in
      *CHANGE_ME*|*change-me*|ff_dev_password|ff-development-token-secret-change-me|ff-development-internal-token-change-me|secret|admin)
        die "$key still contains a development default or placeholder"
        ;;
    esac
    [ "${#value}" -ge 16 ] || die "$key should be at least 16 characters outside development"
  done
fi

require_command docker
resolved="$(mktemp)"
trap 'rm -f "$resolved"' EXIT
compose_cmd "$env_file" config > "$resolved"

if [ "$profile" != "development" ]; then
  if grep -E 'CHANGE_ME|ff_dev_password|ff-development-|demo@ff\.local|Include Error Detail=true|GF_SECURITY_ADMIN_PASSWORD: admin' "$resolved" >/dev/null; then
    die "resolved compose config still contains development defaults or placeholders"
  fi
fi

info "$profile environment is valid"
