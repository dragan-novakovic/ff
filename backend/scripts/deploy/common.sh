#!/usr/bin/env bash

set -euo pipefail

DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$DEPLOY_SCRIPT_DIR/../.." && pwd)"

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

resolve_profile() {
  local profile="${1:-development}"
  case "$profile" in
    development|staging|production) printf '%s\n' "$profile" ;;
    *) die "unknown deployment profile '$profile' (expected development, staging, or production)" ;;
  esac
}

resolve_env_file() {
  local profile="$1"
  local explicit="${2:-}"
  if [ -n "$explicit" ]; then
    [ -f "$explicit" ] || die "env file not found: $explicit"
    cd "$(dirname "$explicit")" && printf '%s/%s\n' "$(pwd)" "$(basename "$explicit")"
    return
  fi

  if [ -f "$BACKEND_DIR/env/$profile.env" ]; then
    printf '%s/env/%s.env\n' "$BACKEND_DIR" "$profile"
  elif [ -f "$BACKEND_DIR/env/$profile.env.example" ]; then
    printf '%s/env/%s.env.example\n' "$BACKEND_DIR" "$profile"
  elif [ "$profile" = "development" ] && [ -f "$BACKEND_DIR/.env" ]; then
    printf '%s/.env\n' "$BACKEND_DIR"
  else
    die "no env file found for profile '$profile'"
  fi
}

load_env_file() {
  local env_file="$1"
  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    if [ -z "${!key-}" ]; then
      export "$key=$value"
    fi
  done < "$env_file"
}

env_value() {
  local key="$1"
  printf '%s' "${!key-}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' was not found"
}

compose_cmd() {
  local env_file="$1"
  shift
  (cd "$BACKEND_DIR" && docker compose --env-file "$env_file" "$@")
}
