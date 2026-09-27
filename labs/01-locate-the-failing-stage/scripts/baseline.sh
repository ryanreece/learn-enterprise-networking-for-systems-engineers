#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

require_docker_daemon
require_lab_node "${ROUTER_CONTAINER}"

if [[ "$(docker exec "${ROUTER_CONTAINER}" cat /proc/sys/net/ipv4/ip_forward)" != 1 ]]; then
  printf '%s\n' 'FAIL: IPv4 forwarding is disabled on the router.' >&2
  exit 1
fi
printf '%s\n' 'PASS: router IPv4 forwarding is enabled.'

expected_route="${WEB_IP} via ${ROUTER_CLIENT_IP}"
actual_route="$(run_on_client ip route get "${WEB_IP}")"
if [[ "${actual_route}" != "${expected_route}"* ]]; then
  printf 'FAIL: client route was %s; expected it through %s.\n' \
    "${actual_route}" "${ROUTER_CLIENT_IP}" >&2
  exit 1
fi
printf 'PASS: client route to %s uses router %s.\n' "${WEB_IP}" "${ROUTER_CLIENT_IP}"

"${LAB_SCRIPT_DIR}/verify.sh"
