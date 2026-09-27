#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_docker_daemon

printf 'Building %s\n' "${NETWORK_TOOLBOX_IMAGE}"
docker build \
  --pull \
  --tag "${NETWORK_TOOLBOX_IMAGE}" \
  "${REPOSITORY_ROOT}/shared/images/network-toolbox"

printf 'Building %s\n' "${LINUX_ROUTER_IMAGE}"
docker build \
  --pull \
  --tag "${LINUX_ROUTER_IMAGE}" \
  "${REPOSITORY_ROOT}/shared/images/linux-router"
