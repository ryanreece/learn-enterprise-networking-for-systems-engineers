#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

require_docker_daemon

printf 'Building %s\n' "${DNS_IMAGE}"
docker build \
  --pull \
  --tag "${DNS_IMAGE}" \
  "${LAB_ROOT}/configs/dns"

docker run \
  --rm \
  --network none \
  --entrypoint /bin/sh \
  "${DNS_IMAGE}" \
  -euc 'command -v coredns >/dev/null && command -v ip >/dev/null'

printf '%s\n' 'Lab 01 DNS image smoke test passed.'
