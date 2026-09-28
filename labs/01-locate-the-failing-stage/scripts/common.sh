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

web_service_is_running() {
  docker exec "${WEB_CONTAINER}" sh -c \
    'test -s /tmp/nginx.pid && kill -0 "$(cat /tmp/nginx.pid)"' \
    >/dev/null 2>&1
}

wait_for_dns_service() {
  local resolved_address

  for _ in {1..20}; do
    resolved_address="$(run_on_client dig \
      +short \
      +time=1 \
      +tries=1 \
      @"${DNS_IP}" \
      "dns.${LAB_ZONE}" A 2>/dev/null | sed -n '1p' || true)"
    if [[ "${resolved_address}" == "${DNS_IP}" ]]; then
      return 0
    fi
    sleep 0.25
  done

  printf '%s\n' 'ERROR: the lab DNS service did not become ready.' >&2
  return 1
}

wait_for_tls_identity() {
  local expected_name="$1"
  local required_matches="${2:-1}"
  local certificate_details
  local consecutive_matches=0

  for _ in {1..40}; do
    certificate_details="$(run_on_client openssl s_client \
      -connect "${WEB_IP}:${APP_PORT}" \
      -servername "${APP_NAME}" </dev/null 2>/dev/null \
      | openssl x509 -noout -ext subjectAltName 2>/dev/null || true)"
    if [[ "${certificate_details}" == *"DNS:${expected_name}"* ]]; then
      consecutive_matches="$((consecutive_matches + 1))"
      if ((consecutive_matches >= required_matches)); then
        return 0
      fi
    else
      consecutive_matches=0
    fi
    sleep 0.25
  done

  printf 'ERROR: HTTPS did not present the expected certificate identity: %s.\n' \
    "${expected_name}" >&2
  return 1
}

wait_for_https_response() {
  local expected_status="$1"
  local expected_body="$2"
  local required_matches="${3:-1}"
  local body
  local consecutive_matches=0
  local http_code
  local output

  for _ in {1..40}; do
    output="$(run_on_client curl \
      --silent \
      --show-error \
      --connect-timeout 1 \
      --max-time 2 \
      --cacert /etc/lab/ca.crt \
      --write-out '|%{http_code}' \
      "https://${APP_NAME}:${APP_PORT}/" 2>/dev/null || true)"
    http_code="${output##*|}"
    body="${output%|*}"
    while [[ "${body}" == *$'\n' ]]; do
      body="${body%$'\n'}"
    done
    if [[ "${http_code}" == "${expected_status}" \
      && "${body}" == "${expected_body}" ]]; then
      consecutive_matches="$((consecutive_matches + 1))"
      if ((consecutive_matches >= required_matches)); then
        return 0
      fi
    else
      consecutive_matches=0
    fi
    sleep 0.25
  done

  printf 'ERROR: HTTPS did not return the expected status and body: %s %s.\n' \
    "${expected_status}" "${expected_body}" >&2
  return 1
}
