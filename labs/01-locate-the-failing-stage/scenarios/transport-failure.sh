#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

wait_for_web_service_to_stop() {
  for _ in {1..20}; do
    if ! web_service_is_running; then
      return 0
    fi
    sleep 0.25
  done

  printf '%s\n' 'ERROR: the HTTPS service did not stop.' >&2
  return 1
}

confirm_failure() {
  local capture_file
  local capture_pid
  local client_route
  local resolved_address
  local web_route

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the transport scenario.' >&2
    return 1
  fi

  client_route="$(run_on_client ip route get "${WEB_IP}")"
  if [[ "${client_route}" != *"via ${ROUTER_CLIENT_IP}"* ]]; then
    printf '%s\n' 'ERROR: the client forward route changed unexpectedly.' >&2
    return 1
  fi

  web_route="$(docker exec "${WEB_CONTAINER}" \
    ip route show exact "${CLIENT_SUBNET}")"
  if [[ "${web_route}" != "${CLIENT_SUBNET} via ${ROUTER_APP_IP}"* ]]; then
    printf '%s\n' 'ERROR: the application return route changed unexpectedly.' >&2
    return 1
  fi

  if docker exec "${ROUTER_CONTAINER}" \
    nft list table inet lab01 >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: scenario-owned router policy changed unexpectedly.' >&2
    return 1
  fi

  docker exec "${WEB_CONTAINER}" nginx -t >/dev/null
  if web_service_is_running; then
    printf '%s\n' 'ERROR: the HTTPS listener is still running.' >&2
    return 1
  fi

  capture_file="$(mktemp "${LAB_STATE_DIR}/transport-capture.XXXXXX")"
  docker exec "${ROUTER_CONTAINER}" \
    timeout 2 tcpdump -nn -l -i eth2 \
    "host ${CLIENT_IP} and host ${WEB_IP} and tcp port ${APP_PORT}" \
    >"${capture_file}" 2>&1 &
  capture_pid=$!
  sleep 0.25

  if run_on_client nc -z -w 1 "${WEB_IP}" "${APP_PORT}" >/dev/null 2>&1; then
    wait "${capture_pid}" || true
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: TCP unexpectedly completed with no HTTPS listener.' >&2
    return 1
  fi
  wait "${capture_pid}" || true

  if ! grep -Fq "> ${WEB_IP}.${APP_PORT}: Flags [S]" "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: no client SYN reached the application segment.' >&2
    return 1
  fi

  if ! awk -v response="${WEB_IP}.${APP_PORT} > ${CLIENT_IP}." '
    index($0, response) && ($0 ~ /Flags \[R\.\]/ || $0 ~ /Flags \[R\]/) {
      found = 1
    }
    END { exit !found }
  ' "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: the application host did not reject the TCP connection.' >&2
    return 1
  fi
  rm -f -- "${capture_file}"
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

  docker exec "${WEB_CONTAINER}" nginx -s quit >/dev/null
  wait_for_web_service_to_stop

  printf '%s\n' transport-failure >"${ACTIVE_SCENARIO_FILE}"
  printf '%s transport-failure: stopped the HTTPS listener on TCP/%s\n' \
    "$(date -Is)" "${APP_PORT}" >>"${DEBUG_LOG}"
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
    printf '%s\n' 'Usage: transport-failure.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
