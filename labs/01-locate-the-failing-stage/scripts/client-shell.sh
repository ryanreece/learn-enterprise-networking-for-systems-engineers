#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

require_command ssh
require_lab_node "${CLIENT_CONTAINER}"

exec ssh \
  -i "${LAB_STATE_DIR}/ssh/id_ed25519" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o "UserKnownHostsFile=${LAB_STATE_DIR}/ssh/known_hosts" \
  "root@${CLIENT_MGMT_IP}"
