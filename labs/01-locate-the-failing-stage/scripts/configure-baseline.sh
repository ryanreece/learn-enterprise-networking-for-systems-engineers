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

configure_interface() {
  local container_name="$1"
  local interface_name="$2"
  local address="$3"

  docker exec "${container_name}" ip address flush dev "${interface_name}"
  docker exec "${container_name}" ip address add "${address}" dev "${interface_name}"
  docker exec "${container_name}" ip link set "${interface_name}" up
}

configure_interface "${CLIENT_CONTAINER}" eth1 "${CLIENT_ROUTER_CIDR}"
configure_interface "${CLIENT_CONTAINER}" eth2 "${CLIENT_DNS_CIDR}"
configure_interface "${ROUTER_CONTAINER}" eth1 "${ROUTER_CLIENT_CIDR}"
configure_interface "${ROUTER_CONTAINER}" eth2 "${ROUTER_APP_CIDR}"
configure_interface "${WEB_CONTAINER}" eth1 "${WEB_CIDR}"
configure_interface "${DNS_CONTAINER}" eth1 "${DNS_CIDR}"

docker exec "${CLIENT_CONTAINER}" \
  ip route replace "${APP_SUBNET}" via "${ROUTER_CLIENT_IP}"
docker exec "${WEB_CONTAINER}" \
  ip route replace "${CLIENT_SUBNET}" via "${ROUTER_APP_IP}"

if [[ "$(docker exec "${ROUTER_CONTAINER}" cat /proc/sys/net/ipv4/ip_forward)" != 1 ]]; then
  printf '%s\n' 'ERROR: IPv4 forwarding is disabled on the router.' >&2
  exit 1
fi

printf '%s\n' 'Applied known-good data-plane addressing and routes.'
