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
"${LAB_SCRIPT_DIR}/scenario.sh" return-route
"${LAB_ROOT}/scenarios/return-route.sh" confirm

# Applying the same scenario again must return to baseline first, then produce
# exactly the same isolated failure.
"${LAB_SCRIPT_DIR}/scenario.sh" return-route
"${LAB_ROOT}/scenarios/return-route.sh" confirm

if "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: verification passed while return-route was active.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/reset.sh"
"${LAB_SCRIPT_DIR}/verify.sh"
"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Return-route lifecycle test passed.'
