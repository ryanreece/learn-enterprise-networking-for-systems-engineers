#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

readonly CERTIFICATE_DIR="${LAB_STATE_DIR}/certificates"
readonly VALID_EXT="${CERTIFICATE_DIR}/valid-server.ext"
readonly WRONG_EXT="${CERTIFICATE_DIR}/wrong-server.ext"

required_files=(
  ca.crt
  ca.key
  valid-server.crt
  valid-server.key
  server.crt
  server.key
  wrong-server.crt
  wrong-server.key
)

certificates_complete=true
for file_name in "${required_files[@]}"; do
  if [[ ! -s "${CERTIFICATE_DIR}/${file_name}" ]]; then
    certificates_complete=false
    break
  fi
done

if [[ "${certificates_complete}" == true ]]; then
  printf '%s\n' 'Lab certificates already exist.'
  exit 0
fi

mkdir -p "${LAB_STATE_DIR}"
temporary_directory="$(mktemp -d "${LAB_STATE_DIR}/certificates.tmp.XXXXXX")"
readonly temporary_directory
trap 'rm -rf -- "${temporary_directory}"' EXIT

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -out "${temporary_directory}/ca.key" >/dev/null 2>&1
openssl req \
  -x509 \
  -new \
  -sha256 \
  -days 3650 \
  -key "${temporary_directory}/ca.key" \
  -subj '/CN=Reece.AI Lab 01 CA' \
  -out "${temporary_directory}/ca.crt"

generate_server_certificate() {
  local file_prefix="$1"
  local common_name="$2"
  local serial_number="$3"
  local extension_file="$4"

  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out "${temporary_directory}/${file_prefix}.key" >/dev/null 2>&1
  openssl req \
    -new \
    -sha256 \
    -key "${temporary_directory}/${file_prefix}.key" \
    -subj "/CN=${common_name}" \
    -out "${temporary_directory}/${file_prefix}.csr"
  openssl x509 \
    -req \
    -sha256 \
    -days 3650 \
    -in "${temporary_directory}/${file_prefix}.csr" \
    -CA "${temporary_directory}/ca.crt" \
    -CAkey "${temporary_directory}/ca.key" \
    -set_serial "${serial_number}" \
    -extfile "${extension_file}" \
    -out "${temporary_directory}/${file_prefix}.crt" >/dev/null 2>&1
  rm -f -- "${temporary_directory}/${file_prefix}.csr"
}

generate_server_certificate valid-server "${APP_NAME}" 0x1001 "${VALID_EXT}"
generate_server_certificate wrong-server "${WRONG_APP_NAME}" 0x1002 "${WRONG_EXT}"
cp -- "${temporary_directory}/valid-server.crt" \
  "${temporary_directory}/server.crt"
cp -- "${temporary_directory}/valid-server.key" \
  "${temporary_directory}/server.key"
chmod 600 "${temporary_directory}"/*.key

mv -- "${VALID_EXT}" "${temporary_directory}/valid-server.ext"
mv -- "${WRONG_EXT}" "${temporary_directory}/wrong-server.ext"
rm -rf -- "${CERTIFICATE_DIR}"
mv -- "${temporary_directory}" "${CERTIFICATE_DIR}"
trap - EXIT

printf 'Generated lab-only certificates in %s\n' "${CERTIFICATE_DIR}"
