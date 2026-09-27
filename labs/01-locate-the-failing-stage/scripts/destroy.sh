#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

require_command containerlab
require_docker_daemon

cd -- "${LAB_ROOT}"
containerlab destroy --topo "${LAB_TOPOLOGY_FILE}" --cleanup

if [[ -d "${LAB_STATE_DIR}" ]]; then
  rm -rf -- "${LAB_STATE_DIR}"
  printf 'Removed generated state: %s\n' "${LAB_STATE_DIR}"
fi

printf '%s\n' 'Lab 01 topology destroyed.'
