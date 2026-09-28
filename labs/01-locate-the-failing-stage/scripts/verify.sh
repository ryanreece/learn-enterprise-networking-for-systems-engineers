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

resolved_address="$(run_on_client dig +short A "${APP_NAME}" | sed -n '1p')"
if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
  printf 'FAIL: %s resolved to %s, expected %s.\n' \
    "${APP_NAME}" "${resolved_address:-no address}" "${WEB_IP}" >&2
  exit 1
fi
printf 'PASS: DNS resolved %s to %s.\n' "${APP_NAME}" "${WEB_IP}"

if ! run_on_client nc -z -w 3 "${APP_NAME}" "${APP_PORT}"; then
  printf 'FAIL: TCP/%s did not connect to %s.\n' "${APP_PORT}" "${APP_NAME}" >&2
  exit 1
fi
printf 'PASS: TCP/%s connected.\n' "${APP_PORT}"

tls_output="$(run_on_client openssl s_client \
  -connect "${APP_NAME}:${APP_PORT}" \
  -servername "${APP_NAME}" \
  -CAfile /etc/lab/ca.crt \
  -verify_hostname "${APP_NAME}" \
  -verify_return_error </dev/null 2>&1 || true)"
if [[ "${tls_output}" != *'Verify return code: 0 (ok)'* ]]; then
  printf 'FAIL: TLS identity or trust validation failed for %s.\n' "${APP_NAME}" >&2
  exit 1
fi
printf 'PASS: TLS identity and trust chain validated.\n'

response="$(run_on_client curl \
  --silent \
  --show-error \
  --fail \
  --connect-timeout 3 \
  --cacert /etc/lab/ca.crt \
  "https://${APP_NAME}:${APP_PORT}/")"
if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
  printf 'FAIL: HTTPS returned %s, expected %s.\n' \
    "${response}" "${EXPECTED_RESPONSE}" >&2
  exit 1
fi
printf 'PASS: HTTPS returned the expected application response.\n'
printf '%s\n' 'Lab 01 verification passed.'
