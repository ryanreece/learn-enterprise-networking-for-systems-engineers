#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${TEST_DIR}/../scripts/common.sh"

policy_output=''

cleanup() {
  "${LAB_SCRIPT_DIR}/destroy.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${LAB_SCRIPT_DIR}/deploy.sh"
"${LAB_SCRIPT_DIR}/baseline.sh"
"${LAB_SCRIPT_DIR}/scenario.sh" policy-drop
"${LAB_ROOT}/scenarios/policy-drop.sh" confirm

# Applying the same scenario again must return to baseline first, then produce
# exactly the same isolated failure.
"${LAB_SCRIPT_DIR}/scenario.sh" policy-drop
"${LAB_ROOT}/scenarios/policy-drop.sh" confirm

if "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: verification passed while policy-drop was active.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/reset.sh"
"${LAB_SCRIPT_DIR}/verify.sh"

if ! router_baseline_policy_is_active; then
  printf '%s\n' 'ERROR: reset did not restore the baseline router policy.' >&2
  exit 1
fi

policy_output="$(docker exec "${ROUTER_CONTAINER}" \
  nft list chain inet "${ROUTER_POLICY_TABLE}" "${ROUTER_POLICY_CHAIN}")"
if [[ "${policy_output}" == *'comment "lab01-policy-drop"'* ]]; then
  printf '%s\n' 'ERROR: reset left the scenario drop rule in place.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Policy-drop lifecycle test passed.'
