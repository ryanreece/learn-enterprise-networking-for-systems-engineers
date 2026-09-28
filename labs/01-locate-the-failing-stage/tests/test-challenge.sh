#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${TEST_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

cleanup() {
  "${LAB_SCRIPT_DIR}/destroy.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

assert_learner_safe_output() {
  local challenge_output="$1"
  local scenario_name

  if [[ "${challenge_output}" != *'Challenge activated.'* ]]; then
    printf '%s\n' 'ERROR: challenge did not print its learner prompt.' >&2
    return 1
  fi
  for scenario_name in "${LAB_SCENARIOS[@]}"; do
    if [[ "${challenge_output}" == *"${scenario_name}"* ]]; then
      printf 'ERROR: challenge output revealed scenario %s.\n' \
        "${scenario_name}" >&2
      return 1
    fi
  done
}

assert_challenge_state() {
  if [[ "$(<"${ACTIVE_SCENARIO_FILE}")" != challenge ]]; then
    printf '%s\n' 'ERROR: challenge state marker revealed its scenario.' >&2
    return 1
  fi
}

"${LAB_SCRIPT_DIR}/deploy.sh"
"${LAB_SCRIPT_DIR}/baseline.sh"

# The internal override exercises every eligible mutation while retaining the
# exact learner-facing behavior of a random challenge.
for scenario_name in "${LAB_SCENARIOS[@]}"; do
  challenge_output="$(LAB_CHALLENGE_SCENARIO="${scenario_name}" \
    "${LAB_SCRIPT_DIR}/challenge.sh" 2>&1)"
  assert_learner_safe_output "${challenge_output}"
  assert_challenge_state
  "${LAB_ROOT}/scenarios/${scenario_name}.sh" confirm

  if "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null 2>&1; then
    printf 'ERROR: verification passed for challenge scenario %s.\n' \
      "${scenario_name}" >&2
    exit 1
  fi

  if ! tail -n 2 "${DEBUG_LOG}" \
    | grep -Fq "challenge: selected ${scenario_name}"; then
    printf 'ERROR: debug log did not record challenge scenario %s.\n' \
      "${scenario_name}" >&2
    exit 1
  fi

  "${LAB_SCRIPT_DIR}/reset.sh"
done

# Exercise the random-selection path and confirm it chooses from the same list.
challenge_output="$("${LAB_SCRIPT_DIR}/challenge.sh" 2>&1)"
assert_learner_safe_output "${challenge_output}"
assert_challenge_state
selected_scenario="$(awk '
  $2 == "challenge:" && $3 == "selected" { selected = $4 }
  END { print selected }
' "${DEBUG_LOG}")"
if ! scenario_is_supported "${selected_scenario}"; then
  printf '%s\n' 'ERROR: random challenge selected an unsupported scenario.' >&2
  exit 1
fi
"${LAB_ROOT}/scenarios/${selected_scenario}.sh" confirm

if "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: verification passed for the random challenge.' >&2
  exit 1
fi

"${LAB_SCRIPT_DIR}/reset.sh"
"${LAB_SCRIPT_DIR}/verify.sh"
"${LAB_SCRIPT_DIR}/destroy.sh"
trap - EXIT

printf '%s\n' 'Challenge-mode lifecycle test passed.'
