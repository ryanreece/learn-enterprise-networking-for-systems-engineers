#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

confirm_failure() {
  local client_route
  local resolved_address
  local tls_output
  local web_route

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the application scenario.' >&2
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

  if ! web_service_is_running; then
    printf '%s\n' 'ERROR: the HTTPS service stopped during the application scenario.' >&2
    return 1
  fi
  docker exec "${WEB_CONTAINER}" nginx -t >/dev/null

  run_on_client nc -z -w 3 "${APP_NAME}" "${APP_PORT}" >/dev/null

  tls_output="$(run_on_client openssl s_client \
    -connect "${APP_NAME}:${APP_PORT}" \
    -servername "${APP_NAME}" \
    -verify_hostname "${APP_NAME}" \
    -verify_return_error </dev/null 2>&1 || true)"
  if [[ "${tls_output}" != *'Verify return code: 0 (ok)'* ]]; then
    printf '%s\n' 'ERROR: TLS changed during the application scenario.' >&2
    return 1
  fi

  wait_for_https_response 500 "${APPLICATION_FAILURE_RESPONSE}"
}

apply_failure() {
  local failure_config

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

  failure_config="$(mktemp "${LAB_STATE_DIR}/web/application-failure.XXXXXX")"
  if ! awk -v response="${APPLICATION_FAILURE_RESPONSE}" '
    $1 == "return" && $2 == "200" {
      printf "            return 500 \"%s\";\n", response
      changed = 1
      next
    }
    { print }
    END { exit !changed }
  ' "${LAB_STATE_DIR}/web/baseline-nginx.conf" >"${failure_config}"; then
    rm -f -- "${failure_config}"
    printf '%s\n' 'ERROR: could not render the application failure.' >&2
    return 1
  fi
  cp -- "${failure_config}" "${LAB_STATE_DIR}/web/nginx.conf"
  rm -f -- "${failure_config}"

  docker exec "${WEB_CONTAINER}" nginx -t >/dev/null
  docker exec "${WEB_CONTAINER}" nginx -s reload
  wait_for_https_response 500 "${APPLICATION_FAILURE_RESPONSE}" 4
  cp -- "${LAB_STATE_DIR}/web/nginx.conf" \
    "${LAB_STATE_DIR}/web/loaded-nginx.conf"

  printf '%s\n' application-failure >"${ACTIVE_SCENARIO_FILE}"
  printf '%s application-failure: configured HTTPS / to return status 500 and body %s\n' \
    "$(date -Is)" "${APPLICATION_FAILURE_RESPONSE}" >>"${DEBUG_LOG}"
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
    printf '%s\n' 'Usage: application-failure.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
