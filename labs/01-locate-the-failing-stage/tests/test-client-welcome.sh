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
help_output="$(docker exec "${CLIENT_CONTAINER}" lab-help)"
sshd_config="$(docker exec "${CLIENT_CONTAINER}" sshd -T)"

if [[ "${help_output}" != "${motd}" ]]; then
  printf '%s\n' 'ERROR: lab-help did not reproduce the client welcome message.' >&2
  exit 1
fi

for expected_text in \
  'Reece.AI Enterprise Networking Lab' \
  'Client:       client' \
  "Application:  ${APP_NAME}" \
  'Objective:    Locate the first failing stage' \
  '  lab-help' \
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

if ! grep -Fqx 'printmotd yes' <<<"${sshd_config}"; then
  printf '%s\n' 'ERROR: client SSH does not enable the login message.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Client welcome-message test passed.'
