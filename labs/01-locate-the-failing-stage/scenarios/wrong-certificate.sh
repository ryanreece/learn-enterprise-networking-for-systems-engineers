#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

confirm_failure() {
  local certificate_details
  local chain_output
  local resolved_address
  local response
  local tls_output

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the certificate scenario.' >&2
    return 1
  fi

  if ! run_on_client ip route get "${WEB_IP}" \
    | grep -Fq "via ${ROUTER_CLIENT_IP}"; then
    printf '%s\n' 'ERROR: the client route changed unexpectedly.' >&2
    return 1
  fi

  if docker exec "${ROUTER_CONTAINER}" \
    nft list table inet lab01 >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: scenario-owned router policy changed unexpectedly.' >&2
    return 1
  fi

  run_on_client nc -z -w 3 "${APP_NAME}" "${APP_PORT}" >/dev/null

  wait_for_tls_identity "${WRONG_APP_NAME}" 4
  certificate_details="$(run_on_client openssl s_client \
    -connect "${APP_NAME}:${APP_PORT}" \
    -servername "${APP_NAME}" </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -ext subjectAltName)"
  if [[ "${certificate_details}" != *"DNS:${WRONG_APP_NAME}"* ]]; then
    printf '%s\n' 'ERROR: HTTPS did not present the intended incorrect identity.' >&2
    return 1
  fi

  chain_output="$(run_on_client openssl s_client \
    -connect "${APP_NAME}:${APP_PORT}" \
    -servername "${APP_NAME}" \
    -CAfile /etc/lab/ca.crt \
    -verify_return_error </dev/null 2>&1 || true)"
  if [[ "${chain_output}" != *'Verify return code: 0 (ok)'* ]]; then
    printf '%s\n' 'ERROR: the incorrect certificate is not signed by the lab CA.' >&2
    return 1
  fi

  tls_output="$(run_on_client openssl s_client \
    -connect "${APP_NAME}:${APP_PORT}" \
    -servername "${APP_NAME}" \
    -CAfile /etc/lab/ca.crt \
    -verify_hostname "${APP_NAME}" \
    -verify_return_error </dev/null 2>&1 || true)"
  if [[ "${tls_output}" != *'hostname mismatch'* ]]; then
    printf '%s\n' 'ERROR: TLS did not fail specifically on hostname validation.' >&2
    return 1
  fi

  response="$(run_on_client curl \
    --silent \
    --show-error \
    --fail \
    --insecure \
    --connect-timeout 3 \
    "https://${APP_NAME}:${APP_PORT}/")"
  if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
    printf '%s\n' 'ERROR: the application changed during the certificate scenario.' >&2
    return 1
  fi

  if run_on_client curl \
    --silent \
    --show-error \
    --fail \
    --connect-timeout 3 \
    --cacert /etc/lab/ca.crt \
    "https://${APP_NAME}:${APP_PORT}/" >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: validated HTTPS unexpectedly accepted the wrong certificate.' >&2
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

  cp -- "${LAB_STATE_DIR}/certificates/wrong-server.crt" \
    "${LAB_STATE_DIR}/certificates/server.crt"
  cp -- "${LAB_STATE_DIR}/certificates/wrong-server.key" \
    "${LAB_STATE_DIR}/certificates/server.key"
  docker exec "${WEB_CONTAINER}" nginx -t >/dev/null
  docker exec "${WEB_CONTAINER}" nginx -s reload

  printf '%s\n' wrong-certificate >"${ACTIVE_SCENARIO_FILE}"
  printf '%s wrong-certificate: activated certificate for %s instead of %s\n' \
    "$(date -Is)" "${WRONG_APP_NAME}" "${APP_NAME}" >>"${DEBUG_LOG}"
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
    printf '%s\n' 'Usage: wrong-certificate.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
