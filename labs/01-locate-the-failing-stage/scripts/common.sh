#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd -- "${LAB_SCRIPT_DIR}/.." && pwd)"
REPOSITORY_ROOT="$(cd -- "${LAB_ROOT}/../.." && pwd)"

# shellcheck source=../../../shared/scripts/common.sh
source "${REPOSITORY_ROOT}/shared/scripts/common.sh"

set -a
# shellcheck source=../configs/lab.env
source "${LAB_ROOT}/configs/lab.env"
set +a

export NETWORK_TOOLBOX_IMAGE
export LINUX_ROUTER_IMAGE

readonly LAB_SCRIPT_DIR
readonly LAB_ROOT
readonly LAB_STATE_DIR="${LAB_ROOT}/.state"
readonly LAB_TOPOLOGY_FILE="${LAB_ROOT}/topology.clab.yml"
readonly CLIENT_CONTAINER="clab-${LAB_NAME}-client"
readonly ROUTER_CONTAINER="clab-${LAB_NAME}-router"
readonly DNS_CONTAINER="clab-${LAB_NAME}-dns"
readonly WEB_CONTAINER="clab-${LAB_NAME}-web"

require_lab_node() {
  local container_name="$1"

  if ! docker container inspect "${container_name}" >/dev/null 2>&1; then
    printf 'ERROR: lab node is not running: %s\n' "${container_name}" >&2
    printf '%s\n' 'Run make deploy first.' >&2
    return 1
  fi
}

run_on_client() {
  docker exec "${CLIENT_CONTAINER}" "$@"
}
