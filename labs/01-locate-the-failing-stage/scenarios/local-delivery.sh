#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

confirm_failure() {
  local capture_file
  local capture_pid
  local client_route
  local neighbor_state
  local resolved_address
  local response
  local web_route

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the local-delivery scenario.' >&2
    return 1
  fi

  client_route="$(run_on_client ip route get "${WEB_IP}")"
  if [[ "${client_route}" != *"via ${BROKEN_CLIENT_GATEWAY_IP}"* \
    || "${client_route}" != *'dev eth1'* ]]; then
    printf '%s\n' 'ERROR: local-delivery mutation is not active.' >&2
    return 1
  fi

  web_route="$(docker exec "${WEB_CONTAINER}" ip route show exact "${CLIENT_SUBNET}")"
  if [[ "${web_route}" != "${CLIENT_SUBNET} via ${ROUTER_APP_IP}"* ]]; then
    printf '%s\n' 'ERROR: the application return route changed unexpectedly.' >&2
    return 1
  fi

  if docker exec "${ROUTER_CONTAINER}" \
    nft list table inet lab01 >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: scenario-owned router policy changed unexpectedly.' >&2
    return 1
  fi

  response="$(docker exec "${WEB_CONTAINER}" \
    wget -q -O - --no-check-certificate "https://127.0.0.1/")"
  if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
    printf '%s\n' 'ERROR: the HTTPS application is not healthy locally.' >&2
    return 1
  fi

  # Clear only the scenario next hop so every confirmation observes fresh
  # neighbor discovery rather than a cached FAILED entry.
  docker exec "${CLIENT_CONTAINER}" \
    ip neighbor del "${BROKEN_CLIENT_GATEWAY_IP}" dev eth1 \
    >/dev/null 2>&1 || true

  capture_file="$(mktemp "${LAB_STATE_DIR}/local-delivery-capture.XXXXXX")"
  docker exec "${CLIENT_CONTAINER}" \
    timeout 2 tcpdump -nn -l -i eth1 \
    "arp or (src host ${CLIENT_IP} and dst host ${WEB_IP} and tcp dst port ${APP_PORT})" \
    >"${capture_file}" 2>&1 &
  capture_pid=$!
  sleep 0.25

  if run_on_client nc -z -w 1 "${WEB_IP}" "${APP_PORT}" >/dev/null 2>&1; then
    wait "${capture_pid}" || true
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: TCP unexpectedly completed with no usable next hop.' >&2
    return 1
  fi
  wait "${capture_pid}" || true

  if ! grep -Fq \
    "who-has ${BROKEN_CLIENT_GATEWAY_IP} tell ${CLIENT_IP}" \
    "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: client did not attempt neighbor discovery for the bad next hop.' >&2
    return 1
  fi

  if grep -Fq "> ${WEB_IP}.${APP_PORT}: Flags [S]" "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: an HTTPS SYN unexpectedly left the client.' >&2
    return 1
  fi
  rm -f -- "${capture_file}"

  neighbor_state="$(run_on_client ip neighbor show \
    "${BROKEN_CLIENT_GATEWAY_IP}" dev eth1)"
  if [[ "${neighbor_state}" != *'INCOMPLETE'* \
    && "${neighbor_state}" != *'FAILED'* ]]; then
    printf '%s\n' 'ERROR: next-hop neighbor state did not show resolution failure.' >&2
    return 1
  fi
}

apply_failure() {
  require_docker_daemon
  for container_name in \
    "${CLIENT_CONTAINER}" \
    "${ROUTER_CONTAINER}" \
    "${DNS_CONTAINER}" \
    "${WEB_CONTAINER}"; do
    require_lab_node "${container_name}"
  done

  "${LAB_SCRIPT_DIR}/render-configs.sh"
  "${LAB_SCRIPT_DIR}/configure-baseline.sh"
  wait_for_dns_service
  "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null

  run_on_client ip route replace "${APP_SUBNET}" \
    via "${BROKEN_CLIENT_GATEWAY_IP}" dev eth1

  printf '%s\n' local-delivery >"${ACTIVE_SCENARIO_FILE}"
  printf '%s local-delivery: changed client next hop for %s from %s to %s\n' \
    "$(date -Is)" "${APP_SUBNET}" "${ROUTER_CLIENT_IP}" \
    "${BROKEN_CLIENT_GATEWAY_IP}" >>"${DEBUG_LOG}"
  confirm_failure
}

case "${1:-}" in
  apply)
    apply_failure
    ;;
  confirm)
    confirm_failure
    ;;
  restore)
    "${LAB_SCRIPT_DIR}/reset.sh"
    ;;
  *)
    printf '%s\n' 'Usage: local-delivery.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
