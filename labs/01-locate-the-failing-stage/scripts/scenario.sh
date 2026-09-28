#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

scenario_name="${1:-}"
if [[ -z "${scenario_name}" ]]; then
  printf '%s\n' 'ERROR: set SCENARIO to a supported scenario.' >&2
  printf 'Supported scenarios: %s\n' "${LAB_SCENARIOS[*]}" >&2
  exit 2
fi

if ! scenario_is_supported "${scenario_name}"; then
  printf 'ERROR: unsupported scenario: %s\n' "${scenario_name}" >&2
  printf 'Supported scenarios: %s\n' "${LAB_SCENARIOS[*]}" >&2
  exit 2
fi

"${LAB_ROOT}/scenarios/${scenario_name}.sh" apply
print_scenario_prompt
