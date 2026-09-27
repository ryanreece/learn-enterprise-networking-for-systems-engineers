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
  local resolved_address
  local response
  local web_route

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the return-route scenario.' >&2
    return 1
  fi

  client_route="$(run_on_client ip route get "${WEB_IP}")"
  if [[ "${client_route}" != *"via ${ROUTER_CLIENT_IP}"* ]]; then
    printf '%s\n' 'ERROR: the client forward route changed unexpectedly.' >&2
    return 1
  fi

  if [[ "$(docker exec "${ROUTER_CONTAINER}" cat /proc/sys/net/ipv4/ip_forward)" != 1 ]]; then
    printf '%s\n' 'ERROR: router forwarding changed unexpectedly.' >&2
    return 1
  fi

  web_route="$(docker exec "${WEB_CONTAINER}" ip route show exact "${CLIENT_SUBNET}")"
  if [[ "${web_route}" != "blackhole ${CLIENT_SUBNET}"* ]]; then
    printf '%s\n' 'ERROR: return-route mutation is not active.' >&2
    return 1
  fi

  response="$(docker exec "${WEB_CONTAINER}" \
    wget -q -O - --no-check-certificate "https://127.0.0.1/")"
  if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
    printf '%s\n' 'ERROR: the HTTPS application is not healthy locally.' >&2
    return 1
  fi

  capture_file="$(mktemp "${LAB_STATE_DIR}/return-route-capture.XXXXXX")"
  docker exec "${ROUTER_CONTAINER}" \
    timeout 2 tcpdump -nn -l -i eth2 \
    "host ${CLIENT_IP} and host ${WEB_IP} and tcp port ${APP_PORT}" \
    >"${capture_file}" 2>&1 &
  capture_pid=$!
  sleep 0.25

  if run_on_client nc -z -w 1 "${WEB_IP}" "${APP_PORT}" >/dev/null 2>&1; then
    wait "${capture_pid}" || true
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: TCP unexpectedly completed with the return-route failure active.' >&2
    return 1
  fi
  wait "${capture_pid}" || true

  if ! grep -Fq "${CLIENT_IP}." "${capture_file}" \
    || ! grep -Fq "> ${WEB_IP}.${APP_PORT}: Flags [S]" "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: no client SYN crossed the router application-side interface.' >&2
    return 1
  fi

  if grep -Fq "${WEB_IP}.${APP_PORT} > ${CLIENT_IP}." "${capture_file}"; then
    rm -f -- "${capture_file}"
    printf '%s\n' 'ERROR: return TCP traffic unexpectedly crossed back through the router.' >&2
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

  docker exec "${WEB_CONTAINER}" \
    ip route replace blackhole "${CLIENT_SUBNET}"

  printf '%s\n' return-route >"${ACTIVE_SCENARIO_FILE}"
  printf '%s return-route: replaced the web route to %s with a blackhole route\n' \
    "$(date -Is)" "${CLIENT_SUBNET}" >>"${DEBUG_LOG}"
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
    printf '%s\n' 'Usage: return-route.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
