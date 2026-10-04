#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

icmp_policy_packet_count=''
https_policy_packet_count=''

require_docker_daemon
require_lab_node "${ROUTER_CONTAINER}"

if [[ "$(docker exec "${ROUTER_CONTAINER}" cat /proc/sys/net/ipv4/ip_forward)" != 1 ]]; then
  printf '%s\n' 'FAIL: IPv4 forwarding is disabled on the router.' >&2
  exit 1
fi
printf '%s\n' 'PASS: router IPv4 forwarding is enabled.'

if ! router_baseline_policy_is_active; then
  printf '%s\n' 'FAIL: explicit router ICMP and HTTPS policy is not active.' >&2
  exit 1
fi
printf '%s\n' 'PASS: explicit router ICMP and HTTPS allow-list policy is active.'

expected_route="${WEB_IP} via ${ROUTER_CLIENT_IP}"
actual_route="$(run_on_client ip route get "${WEB_IP}")"
if [[ "${actual_route}" != "${expected_route}"* ]]; then
  printf 'FAIL: client route was %s; expected it through %s.\n' \
    "${actual_route}" "${ROUTER_CLIENT_IP}" >&2
  exit 1
fi
printf 'PASS: client route to %s uses router %s.\n' "${WEB_IP}" "${ROUTER_CLIENT_IP}"

if ! run_on_client ping -c 2 -W 1 "${WEB_IP}" >/dev/null; then
  printf 'FAIL: ICMP echo requests did not receive replies from %s.\n' \
    "${WEB_IP}" >&2
  exit 1
fi
printf 'PASS: ICMP echo requests received replies from %s.\n' "${WEB_IP}"

"${LAB_SCRIPT_DIR}/verify.sh"

icmp_policy_packet_count="$(router_policy_rule_packet_count \
  "${ROUTER_POLICY_ICMP_COMMENT}")"
if [[ ! "${icmp_policy_packet_count}" =~ ^[0-9]+$ ]] \
  || ((icmp_policy_packet_count < 1)); then
  printf '%s\n' 'FAIL: router ICMP allow rule did not record the verified flow.' >&2
  exit 1
fi
printf 'PASS: explicit router ICMP allow rule recorded %s packet(s).\n' \
  "${icmp_policy_packet_count}"

https_policy_packet_count="$(router_policy_rule_packet_count \
  "${ROUTER_POLICY_HTTPS_COMMENT}")"
if [[ ! "${https_policy_packet_count}" =~ ^[0-9]+$ ]] \
  || ((https_policy_packet_count < 1)); then
  printf '%s\n' 'FAIL: router HTTPS allow rule did not record the verified flow.' >&2
  exit 1
fi
printf 'PASS: explicit router HTTPS allow rule recorded %s packet(s).\n' \
  "${https_policy_packet_count}"
