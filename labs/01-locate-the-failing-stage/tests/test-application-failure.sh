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
"${LAB_SCRIPT_DIR}/baseline.sh"
"${LAB_SCRIPT_DIR}/scenario.sh" application-failure
"${LAB_ROOT}/scenarios/application-failure.sh" confirm

# Applying the same scenario again must return to baseline first, then produce
# exactly the same isolated failure.
"${LAB_SCRIPT_DIR}/scenario.sh" application-failure
"${LAB_ROOT}/scenarios/application-failure.sh" confirm

if "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: verification passed while application-failure was active.' >&2
  exit 1
fi

# Exercise the same configuration repair documented for learners.
cp -- "${LAB_STATE_DIR}/web/baseline-nginx.conf" \
  "${LAB_STATE_DIR}/web/nginx.conf"
docker exec "${WEB_CONTAINER}" nginx -t >/dev/null
docker exec "${WEB_CONTAINER}" nginx -s reload
wait_for_https_response 200 "${EXPECTED_RESPONSE}" 4
"${LAB_SCRIPT_DIR}/verify.sh"

# Prove reset can independently recover the same failure.
"${LAB_SCRIPT_DIR}/scenario.sh" application-failure
"${LAB_SCRIPT_DIR}/reset.sh"
"${LAB_SCRIPT_DIR}/verify.sh"

"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Application-failure lifecycle test passed.'
