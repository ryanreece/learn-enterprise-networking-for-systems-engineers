#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${TEST_DIR}/../scripts/common.sh"

cleanup() {
  "${LAB_SCRIPT_DIR}/destroy.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${LAB_SCRIPT_DIR}/deploy.sh"

motd="$(docker exec "${CLIENT_CONTAINER}" cat /etc/motd)"
help_output="$(docker exec "${CLIENT_CONTAINER}" sh -lc help)"
lab_output="$(docker exec "${CLIENT_CONTAINER}" sh -lc lab)"
diagram_output="$(docker exec "${CLIENT_CONTAINER}" sh -lc 'help diagram')"
addresses_output="$(docker exec "${CLIENT_CONTAINER}" sh -lc 'lab addresses')"
sshd_config="$(docker exec "${CLIENT_CONTAINER}" sshd -T)"

if [[ "${help_output}" != "${motd}" ]]; then
  printf '%s\n' 'ERROR: help did not reproduce the client welcome message.' >&2
  exit 1
fi

if [[ "${lab_output}" != "${motd}" ]]; then
  printf '%s\n' 'ERROR: bare lab did not reproduce the client welcome message.' >&2
  exit 1
fi

for expected_text in \
  'Reece.AI Enterprise Networking Lab' \
  'Client:       client' \
  "Application:  ${APP_NAME}" \
  'Objective:    Locate the first failing stage' \
  '  help                              Show this message' \
  '  help diagram                      Show the lab topology' \
  '  lab addresses                     Show the lab address table' \
  "  dig ${APP_NAME}" \
  '  ip route' \
  '  ip neighbor' \
  "  curl -v --cacert /etc/lab/ca.crt https://${APP_NAME}/" \
  "  openssl s_client -connect ${APP_NAME}:${APP_PORT} -servername ${APP_NAME}"; do
  if ! grep -Fqx -- "${expected_text}" <<<"${motd}"; then
    printf 'ERROR: client welcome message is missing: %s\n' \
      "${expected_text}" >&2
    exit 1
  fi
done

for expected_text in \
  'client' \
  'router/firewall' \
  'dns' \
  "web / ${APP_NAME}" \
  "DNS segment ${DNS_SUBNET}" \
  "Client segment ${CLIENT_SUBNET}" \
  "Application segment ${APP_SUBNET}"; do
  if [[ "${diagram_output}" != *"${expected_text}"* ]]; then
    printf 'ERROR: lab diagram is missing: %s\n' "${expected_text}" >&2
    exit 1
  fi
done

for expected_text in \
  '| Node   | Interface  | Address         | Network          |' \
  "${CLIENT_MGMT_IP}" \
  "${CLIENT_ROUTER_CIDR}" \
  "${CLIENT_DNS_CIDR}" \
  "${ROUTER_MGMT_IP}" \
  "${ROUTER_CLIENT_CIDR}" \
  "${ROUTER_APP_CIDR}" \
  "${DNS_MGMT_IP}" \
  "${DNS_CIDR}" \
  "${WEB_MGMT_IP}" \
  "${WEB_CIDR}"; do
  if [[ "${addresses_output}" != *"${expected_text}"* ]]; then
    printf 'ERROR: lab address table is missing: %s\n' "${expected_text}" >&2
    exit 1
  fi
done

if docker exec "${CLIENT_CONTAINER}" sh -lc 'help unknown' >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: help accepted an unsupported subcommand.' >&2
  exit 1
fi

if docker exec "${CLIENT_CONTAINER}" sh -lc 'lab unknown' >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: lab accepted an unsupported subcommand.' >&2
  exit 1
fi

if ! grep -Fqx 'printmotd yes' <<<"${sshd_config}"; then
  printf '%s\n' 'ERROR: client SSH does not enable the login message.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Client welcome-message test passed.'
