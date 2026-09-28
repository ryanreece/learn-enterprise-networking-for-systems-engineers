#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

readonly SCRIPT_DIR
readonly REPOSITORY_ROOT
readonly NETWORK_TOOLBOX_IMAGE="${NETWORK_TOOLBOX_IMAGE:-reeceai-course/network-toolbox:0.3.0}"
readonly LINUX_ROUTER_IMAGE="${LINUX_ROUTER_IMAGE:-reeceai-course/linux-router:0.1.0}"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "${command_name}" >&2
    return 1
  fi
}

require_docker_daemon() {
  require_command docker

  if ! docker info >/dev/null 2>&1; then
    printf '%s\n' \
      'ERROR: Docker is installed, but this user cannot reach the daemon.' \
      'See docs/troubleshooting-the-lab-environment.md.' >&2
    return 1
  fi
}
