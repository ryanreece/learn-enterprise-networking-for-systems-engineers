#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

app_record="${APP_NAME%."${LAB_ZONE}"}"
if [[ "${app_record}" == "${APP_NAME}" || "${app_record}" == *.* ]]; then
  printf 'ERROR: APP_NAME must be one label beneath LAB_ZONE: %s beneath %s\n' \
    "${APP_NAME}" "${LAB_ZONE}" >&2
  exit 1
fi
readonly app_record

zone_serial="$(date +%s)"
if [[ -s "${LAB_STATE_DIR}/dns/db.lab.test" ]]; then
  current_serial="$(awk '$2 == ";" && $3 == "serial" {print $1; exit}' \
    "${LAB_STATE_DIR}/dns/db.lab.test")"
  if [[ "${current_serial}" =~ ^[0-9]+$ ]] \
    && ((current_serial >= zone_serial)); then
    zone_serial="$((current_serial + 1))"
  fi
fi
readonly zone_serial

mkdir -p "${LAB_STATE_DIR}/certificates" \
  "${LAB_STATE_DIR}/client" \
  "${LAB_STATE_DIR}/dns" \
  "${LAB_STATE_DIR}/web"

printf 'nameserver %s\noptions attempts:1 timeout:1\n' "${DNS_IP}" \
  >"${LAB_STATE_DIR}/client/resolv.conf"

printf '%s\n' \
  "\$ORIGIN ${LAB_ZONE}." \
  "\$TTL 60" \
  "@ IN SOA dns.${LAB_ZONE}. admin.${LAB_ZONE}. (" \
  "    ${zone_serial} ; serial" \
  '    60 60 60 60' \
  ')' \
  "@ IN NS dns.${LAB_ZONE}." \
  "dns IN A ${DNS_IP}" \
  "${app_record} IN A ${WEB_IP}" \
  >"${LAB_STATE_DIR}/dns/db.lab.test"

sed "s/__LAB_ZONE__/${LAB_ZONE}/g" \
  "${LAB_ROOT}/configs/dns/Corefile.template" \
  >"${LAB_STATE_DIR}/dns/Corefile"

sed \
  -e "s/__APP_NAME__/${APP_NAME}/g" \
  -e "s/__APP_PORT__/${APP_PORT}/g" \
  -e "s/__EXPECTED_RESPONSE__/${EXPECTED_RESPONSE}/g" \
  "${LAB_ROOT}/configs/web/nginx.conf.template" \
  >"${LAB_STATE_DIR}/web/baseline-nginx.conf"
cp -- "${LAB_STATE_DIR}/web/baseline-nginx.conf" \
  "${LAB_STATE_DIR}/web/nginx.conf"

sed "s/__APP_NAME__/${APP_NAME}/g" \
  "${LAB_ROOT}/configs/certificates/valid-server.ext.template" \
  >"${LAB_STATE_DIR}/certificates/valid-server.ext"

sed "s/__WRONG_APP_NAME__/${WRONG_APP_NAME}/g" \
  "${LAB_ROOT}/configs/certificates/wrong-server.ext.template" \
  >"${LAB_STATE_DIR}/certificates/wrong-server.ext"
