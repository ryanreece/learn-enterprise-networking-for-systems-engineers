#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ZONE_FILE="${LAB_STATE_DIR}/dns/db.lab.test"
readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

confirm_failure() {
  local dns_status
  local resolved_address
  local response

  for _ in {1..20}; do
    dns_status="$(run_on_client dig \
      +time=1 \
      +tries=1 \
      +noall \
      +comments \
      "${APP_NAME}" A 2>/dev/null || true)"
    if [[ "${dns_status}" == *'status: NXDOMAIN'* ]]; then
      break
    fi
    sleep 0.25
  done
  if [[ "${dns_status}" != *'status: NXDOMAIN'* ]]; then
    printf 'ERROR: DNS scenario did not produce NXDOMAIN for %s.\n' "${APP_NAME}" >&2
    return 1
  fi

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    @"${DNS_IP}" \
    "dns.${LAB_ZONE}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${DNS_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS service health check failed.' >&2
    return 1
  fi

  run_on_client nc -z -w 3 "${WEB_IP}" "${APP_PORT}" >/dev/null
  run_on_client openssl s_client \
    -connect "${WEB_IP}:${APP_PORT}" \
    -servername "${APP_NAME}" \
    -CAfile /etc/lab/ca.crt \
    -verify_hostname "${APP_NAME}" \
    -verify_return_error </dev/null 2>&1 \
    | grep -q 'Verify return code: 0 (ok)'

  response="$(run_on_client curl \
    --silent \
    --show-error \
    --fail \
    --connect-timeout 3 \
    --cacert /etc/lab/ca.crt \
    --resolve "${APP_NAME}:${APP_PORT}:${WEB_IP}" \
    "https://${APP_NAME}:${APP_PORT}/")"
  if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
    printf '%s\n' 'ERROR: application health changed during the DNS scenario.' >&2
    return 1
  fi
}

apply_failure() {
  local app_record
  local next_serial
  local temporary_zone

  require_docker_daemon
  require_lab_node "${CLIENT_CONTAINER}"
  require_lab_node "${DNS_CONTAINER}"

  "${LAB_SCRIPT_DIR}/render-configs.sh"
  "${LAB_SCRIPT_DIR}/configure-baseline.sh"
  wait_for_dns_service
  "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null

  app_record="${APP_NAME%."${LAB_ZONE}"}"
  next_serial="$(awk '$2 == ";" && $3 == "serial" {print $1 + 1; exit}' "${ZONE_FILE}")"
  temporary_zone="$(mktemp "${LAB_STATE_DIR}/dns/db.lab.test.XXXXXX")"
  awk -v record="${app_record}" -v serial="${next_serial}" '
    $1 == record && $2 == "IN" && $3 == "A" {next}
    $2 == ";" && $3 == "serial" {$1 = serial}
    {print}
  ' \
    "${ZONE_FILE}" >"${temporary_zone}"
  cp -- "${temporary_zone}" "${ZONE_FILE}"
  rm -f -- "${temporary_zone}"

  if grep -Eq "^${app_record}[[:space:]]+IN[[:space:]]+A[[:space:]]" "${ZONE_FILE}"; then
    printf '%s\n' 'ERROR: failed to activate the DNS scenario.' >&2
    return 1
  fi

  printf '%s\n' dns-failure >"${ACTIVE_SCENARIO_FILE}"
  printf '%s dns-failure: removed %s A record from %s\n' \
    "$(date -Is)" "${APP_NAME}" "${ZONE_FILE}" >>"${DEBUG_LOG}"
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
    printf '%s\n' 'Usage: dns-failure.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
