#!/usr/bin/env bash
set -euo pipefail

LAB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${LAB_SCRIPT_DIR}/common.sh"

readonly SSH_STATE_DIR="${LAB_STATE_DIR}/ssh"

required_files=(
  authorized_keys
  id_ed25519
  id_ed25519.pub
  ssh_host_ed25519_key
  ssh_host_ed25519_key.pub
)

keys_complete=true
for file_name in "${required_files[@]}"; do
  if [[ ! -s "${SSH_STATE_DIR}/${file_name}" ]]; then
    keys_complete=false
    break
  fi
done

if [[ "${keys_complete}" == true ]]; then
  printf '%s\n' 'Lab SSH keys already exist.'
  exit 0
fi

mkdir -p "${LAB_STATE_DIR}"
temporary_directory="$(mktemp -d "${LAB_STATE_DIR}/ssh.tmp.XXXXXX")"
readonly temporary_directory
trap 'rm -rf -- "${temporary_directory}"' EXIT

ssh-keygen \
  -q \
  -t ed25519 \
  -N '' \
  -C 'reece-ai-lab01-client' \
  -f "${temporary_directory}/id_ed25519"
ssh-keygen \
  -q \
  -t ed25519 \
  -N '' \
  -C 'reece-ai-lab01-client-host' \
  -f "${temporary_directory}/ssh_host_ed25519_key"
cp -- "${temporary_directory}/id_ed25519.pub" \
  "${temporary_directory}/authorized_keys"
chmod 700 "${temporary_directory}"
chmod 600 "${temporary_directory}/id_ed25519" \
  "${temporary_directory}/ssh_host_ed25519_key"

rm -rf -- "${SSH_STATE_DIR}"
mv -- "${temporary_directory}" "${SSH_STATE_DIR}"
trap - EXIT

printf 'Generated lab-only SSH keys in %s\n' "${SSH_STATE_DIR}"
