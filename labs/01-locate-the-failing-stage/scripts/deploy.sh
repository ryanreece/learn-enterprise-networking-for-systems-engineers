#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

"${LAB_SCRIPT_DIR}/check-prerequisites.sh"

for image in "${NETWORK_TOOLBOX_IMAGE}" "${LINUX_ROUTER_IMAGE}" "${DNS_IMAGE}"; do
  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    printf 'ERROR: required local image is missing: %s\n' "${image}" >&2
    printf '%s\n' 'Run make build first.' >&2
    exit 1
  fi
done

"${LAB_SCRIPT_DIR}/render-configs.sh"
"${LAB_SCRIPT_DIR}/generate-certificates.sh"

cd -- "${LAB_ROOT}"
containerlab deploy --topo "${LAB_TOPOLOGY_FILE}" --reconfigure
"${LAB_SCRIPT_DIR}/configure-baseline.sh"

printf '%s\n' 'Known-good Lab 01 topology deployed.'
printf '%s\n' 'Run make baseline to verify the complete transaction.'
