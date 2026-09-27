#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

require_docker_daemon
for container_name in \
  "${CLIENT_CONTAINER}" \
  "${ROUTER_CONTAINER}" \
  "${DNS_CONTAINER}" \
  "${WEB_CONTAINER}"; do
  require_lab_node "${container_name}"
done

"${LAB_SCRIPT_DIR}/render-configs.sh"
"${LAB_SCRIPT_DIR}/configure-baseline.sh"
wait_for_dns_service
rm -f -- "${LAB_STATE_DIR}/active-scenario"

"${LAB_SCRIPT_DIR}/verify.sh"
printf '%s\n' 'Known-good Lab 01 state restored.'
