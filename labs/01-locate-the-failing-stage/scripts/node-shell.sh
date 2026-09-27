#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

case "${1:-}" in
  router)
    container_name="${ROUTER_CONTAINER}"
    shell_path=/bin/bash
    ;;
  server)
    container_name="${WEB_CONTAINER}"
    shell_path=/bin/sh
    ;;
  *)
    printf '%s\n' 'Usage: node-shell.sh router|server' >&2
    exit 2
    ;;
esac

require_lab_node "${container_name}"
exec docker exec -it "${container_name}" "${shell_path}"
