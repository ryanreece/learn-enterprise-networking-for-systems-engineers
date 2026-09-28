#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

scenario_name="${1:-}"
if [[ -z "${scenario_name}" ]]; then
  printf '%s\n' 'ERROR: set SCENARIO to a supported scenario.' >&2
  printf '%s\n' \
    'Supported scenarios: dns-failure, local-delivery, return-route, policy-drop, wrong-certificate' >&2
  exit 2
fi

case "${scenario_name}" in
  dns-failure)
    "${LAB_ROOT}/scenarios/dns-failure.sh" apply
    ;;
  local-delivery)
    "${LAB_ROOT}/scenarios/local-delivery.sh" apply
    ;;
  return-route)
    "${LAB_ROOT}/scenarios/return-route.sh" apply
    ;;
  policy-drop)
    "${LAB_ROOT}/scenarios/policy-drop.sh" apply
    ;;
  wrong-certificate)
    "${LAB_ROOT}/scenarios/wrong-certificate.sh" apply
    ;;
  *)
    printf 'ERROR: unsupported scenario: %s\n' "${scenario_name}" >&2
    printf '%s\n' \
      'Supported scenarios: dns-failure, local-delivery, return-route, policy-drop, wrong-certificate' >&2
    exit 2
    ;;
esac

printf '%s\n' \
  'Scenario activated.' \
  '' \
  'Observed symptom:' \
  "  The client cannot complete an HTTPS connection to ${APP_NAME}." \
  '' \
  'Your task:' \
  '  1. Identify the last working stage.' \
  '  2. Collect evidence for the failing stage.' \
  '  3. Repair the environment.' \
  '  4. Run make verify.'
