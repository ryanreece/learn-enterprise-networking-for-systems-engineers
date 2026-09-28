#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly APPLY_LOG="${LAB_STATE_DIR}/challenge-apply.log"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"

if [[ ! -d "${LAB_STATE_DIR}" ]]; then
  printf '%s\n' 'ERROR: Lab 01 is not deployed. Run make deploy first.' >&2
  exit 1
fi

selected_scenario="${LAB_CHALLENGE_SCENARIO:-}"
if [[ -n "${selected_scenario}" ]]; then
  if ! scenario_is_supported "${selected_scenario}"; then
    printf '%s\n' 'ERROR: invalid internal challenge scenario override.' >&2
    exit 2
  fi
else
  selected_scenario="${LAB_SCENARIOS[RANDOM % ${#LAB_SCENARIOS[@]}]}"
fi
readonly selected_scenario

if ! "${LAB_ROOT}/scenarios/${selected_scenario}.sh" apply \
  >"${APPLY_LOG}" 2>&1; then
  printf '%s\n' \
    'ERROR: challenge activation failed.' \
    "Diagnostic output was written to ${APPLY_LOG}." >&2
  exit 1
fi

# Do not leave the selected name in the learner-facing state marker. Detailed
# selection and mutation evidence remains in the ignored instructor/debug log.
printf '%s\n' challenge >"${ACTIVE_SCENARIO_FILE}"
printf '%s challenge: selected %s\n' \
  "$(date -Is)" "${selected_scenario}" >>"${DEBUG_LOG}"

print_scenario_prompt 'Challenge activated.'
