#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

for command_name in docker containerlab openssl make; do
  require_command "${command_name}"
done

require_docker_daemon

if [[ "$(uname -s)" != Linux ]]; then
  printf '%s\n' 'ERROR: Part B requires a native Linux host or Linux VM.' >&2
  exit 1
fi

if [[ ! -r /proc/sys/net/ipv4/ip_forward ]]; then
  printf '%s\n' 'ERROR: the host does not expose the IPv4 forwarding sysctl.' >&2
  exit 1
fi

printf 'Docker:       %s\n' "$(docker version --format '{{.Server.Version}}')"
printf 'Containerlab: %s\n' "$(containerlab version 2>/dev/null | awk '/version:/ {print $2; exit}')"
printf 'OpenSSL:      %s\n' "$(openssl version | awk '{print $2}')"
printf '%s\n' 'Lab 01 prerequisite check passed.'
