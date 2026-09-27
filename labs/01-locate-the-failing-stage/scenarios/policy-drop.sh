#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/common.sh
source "${SCENARIO_DIR}/../scripts/common.sh"

readonly ACTIVE_SCENARIO_FILE="${LAB_STATE_DIR}/active-scenario"
readonly DEBUG_LOG="${LAB_STATE_DIR}/scenario-debug.log"
readonly POLICY_TABLE=lab01
readonly POLICY_CHAIN=forward
readonly POLICY_COMMENT=lab01-policy-drop

confirm_failure() {
  local app_side_capture
  local app_side_pid
  local client_route
  local client_side_capture
  local client_side_pid
  local packet_count
  local resolved_address
  local response
  local rule_output
  local web_route

  resolved_address="$(run_on_client dig \
    +short \
    +time=1 \
    +tries=1 \
    "${APP_NAME}" A | sed -n '1p')"
  if [[ "${resolved_address}" != "${WEB_IP}" ]]; then
    printf '%s\n' 'ERROR: DNS changed during the policy-drop scenario.' >&2
    return 1
  fi

  client_route="$(run_on_client ip route get "${WEB_IP}")"
  if [[ "${client_route}" != *"via ${ROUTER_CLIENT_IP}"* ]]; then
    printf '%s\n' 'ERROR: the client forward route changed unexpectedly.' >&2
    return 1
  fi

  web_route="$(docker exec "${WEB_CONTAINER}" ip route show exact "${CLIENT_SUBNET}")"
  if [[ "${web_route}" != "${CLIENT_SUBNET} via ${ROUTER_APP_IP}"* ]]; then
    printf '%s\n' 'ERROR: the application return route changed unexpectedly.' >&2
    return 1
  fi

  if [[ "$(docker exec "${ROUTER_CONTAINER}" cat /proc/sys/net/ipv4/ip_forward)" != 1 ]]; then
    printf '%s\n' 'ERROR: router forwarding changed unexpectedly.' >&2
    return 1
  fi

  response="$(docker exec "${WEB_CONTAINER}" \
    wget -q -O - --no-check-certificate "https://127.0.0.1/")"
  if [[ "${response}" != "${EXPECTED_RESPONSE}" ]]; then
    printf '%s\n' 'ERROR: the HTTPS application is not healthy locally.' >&2
    return 1
  fi

  rule_output="$(docker exec "${ROUTER_CONTAINER}" \
    nft list chain inet "${POLICY_TABLE}" "${POLICY_CHAIN}")"
  if [[ "${rule_output}" != *"comment \"${POLICY_COMMENT}\""* ]]; then
    printf '%s\n' 'ERROR: policy-drop rule is not active.' >&2
    return 1
  fi

  client_side_capture="$(mktemp "${LAB_STATE_DIR}/policy-client-side.XXXXXX")"
  app_side_capture="$(mktemp "${LAB_STATE_DIR}/policy-app-side.XXXXXX")"

  docker exec "${ROUTER_CONTAINER}" \
    timeout 2 tcpdump -nn -l -i eth1 \
    "src host ${CLIENT_IP} and dst host ${WEB_IP} and tcp dst port ${APP_PORT}" \
    >"${client_side_capture}" 2>&1 &
  client_side_pid=$!
  docker exec "${ROUTER_CONTAINER}" \
    timeout 2 tcpdump -nn -l -i eth2 \
    "src host ${CLIENT_IP} and dst host ${WEB_IP} and tcp dst port ${APP_PORT}" \
    >"${app_side_capture}" 2>&1 &
  app_side_pid=$!
  sleep 0.25

  if run_on_client nc -z -w 1 "${WEB_IP}" "${APP_PORT}" >/dev/null 2>&1; then
    wait "${client_side_pid}" || true
    wait "${app_side_pid}" || true
    rm -f -- "${client_side_capture}" "${app_side_capture}"
    printf '%s\n' 'ERROR: TCP unexpectedly completed with the policy drop active.' >&2
    return 1
  fi
  wait "${client_side_pid}" || true
  wait "${app_side_pid}" || true

  if ! grep -Fq "> ${WEB_IP}.${APP_PORT}: Flags [S]" "${client_side_capture}"; then
    rm -f -- "${client_side_capture}" "${app_side_capture}"
    printf '%s\n' 'ERROR: no client SYN reached the router client-side interface.' >&2
    return 1
  fi

  if grep -Fq "> ${WEB_IP}.${APP_PORT}: Flags [S]" "${app_side_capture}"; then
    rm -f -- "${client_side_capture}" "${app_side_capture}"
    printf '%s\n' 'ERROR: a dropped SYN unexpectedly crossed the policy boundary.' >&2
    return 1
  fi
  rm -f -- "${client_side_capture}" "${app_side_capture}"

  rule_output="$(docker exec "${ROUTER_CONTAINER}" \
    nft list chain inet "${POLICY_TABLE}" "${POLICY_CHAIN}")"
  packet_count="$(awk -v comment="${POLICY_COMMENT}" '
    index($0, "comment \"" comment "\"") {
      for (field = 1; field <= NF; field++) {
        if ($field == "packets") {
          print $(field + 1)
          exit
        }
      }
    }
  ' <<<"${rule_output}")"
  if [[ ! "${packet_count}" =~ ^[0-9]+$ ]] || ((packet_count < 1)); then
    printf '%s\n' 'ERROR: policy-drop counter did not record the failed flow.' >&2
    return 1
  fi
}

apply_failure() {
  require_docker_daemon
  for container_name in \
    "${CLIENT_CONTAINER}" \
    "${ROUTER_CONTAINER}" \
    "${DNS_CONTAINER}" \
    "${WEB_CONTAINER}"; do
    require_lab_node "${container_name}"
  done

  "${LAB_SCRIPT_DIR}/render-configs.sh"
  "${LAB_SCRIPT_DIR}/configure-baseline.sh"
  wait_for_dns_service
  "${LAB_SCRIPT_DIR}/verify.sh" >/dev/null

  docker exec "${ROUTER_CONTAINER}" nft add table inet "${POLICY_TABLE}"
  docker exec "${ROUTER_CONTAINER}" nft \
    "add chain inet ${POLICY_TABLE} ${POLICY_CHAIN} { type filter hook forward priority 0; policy accept; }"
  docker exec "${ROUTER_CONTAINER}" nft \
    "add rule inet ${POLICY_TABLE} ${POLICY_CHAIN} ip saddr ${CLIENT_IP} ip daddr ${WEB_IP} tcp dport ${APP_PORT} counter drop comment \"${POLICY_COMMENT}\""

  printf '%s\n' policy-drop >"${ACTIVE_SCENARIO_FILE}"
  printf '%s policy-drop: installed nftables rule %s for %s to %s TCP/%s\n' \
    "$(date -Is)" "${POLICY_COMMENT}" "${CLIENT_IP}" "${WEB_IP}" \
    "${APP_PORT}" >>"${DEBUG_LOG}"
  confirm_failure
}

case "${1:-}" in
  apply)
    apply_failure
    ;;
  confirm)
    confirm_failure
    ;;
  restore)
    "${LAB_SCRIPT_DIR}/reset.sh"
    ;;
  *)
    printf '%s\n' 'Usage: policy-drop.sh apply|confirm|restore' >&2
    exit 2
    ;;
esac
