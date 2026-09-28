#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_docker_daemon

test_commands() {
  local image="$1"
  shift

  printf 'Testing %s\n' "${image}"
  docker run \
    --rm \
    --network none \
    --cap-drop ALL \
    "${image}" \
    sh -euc 'for command_name in "$@"; do command -v "${command_name}" >/dev/null; done' \
    sh "$@"
}

test_label() {
  local image="$1"
  local label="$2"
  local expected="$3"
  local actual

  actual="$(docker image inspect --format "{{ index .Config.Labels \"${label}\" }}" "${image}")"
  if [[ "${actual}" != "${expected}" ]]; then
    printf 'ERROR: %s label %s was %s, expected %s\n' \
      "${image}" "${label}" "${actual}" "${expected}" >&2
    return 1
  fi
}

test_commands \
  "${NETWORK_TOOLBOX_IMAGE}" \
  bash dig curl ip ping traceroute nc openssl sshd ssh-keygen tcpdump \
  update-ca-certificates

test_commands \
  "${LINUX_ROUTER_IMAGE}" \
  bash conntrack ip ping nft tcpdump

for image in "${NETWORK_TOOLBOX_IMAGE}" "${LINUX_ROUTER_IMAGE}"; do
  test_label "${image}" org.opencontainers.image.licenses MIT
  test_label \
    "${image}" \
    org.opencontainers.image.source \
    https://gitlab.int.reece.ai/ryanreece/learn-enterprise-networking-for-systems-engineers
done

printf 'Testing toolbox SSH configuration\n'
docker run \
  --rm \
  --network none \
  --cap-drop ALL \
  --entrypoint /bin/sh \
  "${NETWORK_TOOLBOX_IMAGE}" \
  -euc '
    ssh-keygen -A >/dev/null 2>&1
    mkdir -p /run/sshd
    sshd -t
    grep -Fx "PrintMotd yes" /etc/ssh/sshd_config >/dev/null
  '

printf 'Testing toolbox capability boundary\n'
docker run \
  --rm \
  --network none \
  --cap-drop ALL \
  --cap-add NET_RAW \
  "${NETWORK_TOOLBOX_IMAGE}" \
  sh -euc 'ping -c 1 127.0.0.1 >/dev/null && tcpdump -D >/dev/null'

printf 'Testing router capability boundary\n'
docker run \
  --rm \
  --network none \
  --cap-drop ALL \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --sysctl net.ipv4.ip_forward=1 \
  "${LINUX_ROUTER_IMAGE}" \
  sh -euc '
    test "$(cat /proc/sys/net/ipv4/ip_forward)" = 1
    nft add table inet image_smoke_test
    nft list table inet image_smoke_test >/dev/null
    nft delete table inet image_smoke_test
    conntrack --count >/dev/null
    tcpdump -D >/dev/null
  '

printf '%s\n' 'Shared image smoke tests passed.'
