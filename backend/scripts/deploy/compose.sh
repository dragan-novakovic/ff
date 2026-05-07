#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

profile="$(resolve_profile "${1:-development}")"
shift || true
env_file="$(resolve_env_file "$profile")"

"$DEPLOY_SCRIPT_DIR/check-env.sh" "$profile" "$env_file"
load_env_file "$env_file"

if [ "$profile" != "development" ]; then
  for arg in "$@"; do
    if [ "$arg" = "--build" ] || [ "$arg" = "build" ]; then
      die "building images from local source is disabled for $profile; publish immutable images and set FF_IMAGE_TAG"
    fi
  done
fi

if [ "$#" -eq 0 ]; then
  set -- config
fi

compose_cmd "$env_file" "$@"
