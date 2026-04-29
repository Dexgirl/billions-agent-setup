#!/usr/bin/env bash
# restore-default-did.sh
# Interactive recovery tool for users who already ran the v1.0.4 upgrade
# and silently lost their linked default DID.
# See: https://github.com/BillionsNetwork/verified-agent-identity/issues/571

set -euo pipefail

STORAGE_DIR="${HOME}/.openclaw/billions"
BACKUP_ROOT="${STORAGE_DIR}/upgrade-log"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_CYN=$'\033[36m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_CYN=""; C_DIM=""; C_BLD=""; C_RST=""
fi

ok()   { echo "${C_GRN}✓${C_RST} $*"; }
warn() { echo "${C_YLW}⚠${C_RST} $*"; }
err()  { echo "${C_RED}✗${C_RST} $*" >&2; }

if [[ ! -f "${STORAGE_DIR}/identities.json" ]]; then
  err "identities.json not found at ${STORAGE_DIR}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required. Install with: sudo apt install jq"
  exit 1
fi

CURRENT_DEFAULT=""
if [[ -f "${STORAGE_DIR}/defaultDid.json" ]]; then
  CURRENT_DEFAULT="$(jq -r '.did // empty' "${STORAGE_DIR}/defaultDid.json")"
fi

mapfile -t DIDS < <(jq -r '.[].did' "${STORAGE_DIR}/identities.json")

if [[ ${#DIDS[@]} -eq 0 ]]; then
  err "No identities found in identities.json"
  exit 1
fi

echo "${C_BLD}Identities found in ${STORAGE_DIR}/identities.json:${C_RST}"
echo

for i in "${!DIDS[@]}"; do
  num=$((i + 1))
  did="${DIDS[$i]}"
  short="${did: -8}"
  marker=""
  if [[ "${did}" == "${CURRENT_DEFAULT}" ]]; then
    marker="${C_CYN}[CURRENT DEFAULT]${C_RST}"
  fi
  printf "  ${C_BLD}%d)${C_RST} ...%s  ${C_DIM}%s${C_RST} %s\n" "${num}" "${short}" "${did}" "${marker}"
done

echo
echo "Which identity should be set as default?"
echo "Enter the number (1-${#DIDS[@]}), or 'q' to quit without changes."
read -r -p "> " choice

if [[ "${choice}" == "q" || "${choice}" == "Q" ]]; then
  echo "Aborted. No changes made."
  exit 0
fi

if ! [[ "${choice}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DIDS[@]} )); then
  err "Invalid choice: ${choice}"
  exit 1
fi

selected_did="${DIDS[$((choice - 1))]}"

if [[ "${selected_did}" == "${CURRENT_DEFAULT}" ]]; then
  ok "That DID is already the default. Nothing to do."
  exit 0
fi

mkdir -p "${BACKUP_ROOT}/${TS}"
if [[ -f "${STORAGE_DIR}/defaultDid.json" ]]; then
  cp "${STORAGE_DIR}/defaultDid.json" "${BACKUP_ROOT}/${TS}/defaultDid.json"
  ok "Backed up old defaultDid.json to ${BACKUP_ROOT}/${TS}/"
fi

pub_key="$(jq -r --arg d "${selected_did}" '.[] | select(.did == $d) | .publicKeyHex // empty' "${STORAGE_DIR}/identities.json")"

if [[ -n "${pub_key}" ]]; then
  jq -n --arg did "${selected_did}" --arg pk "${pub_key}" \
    '{did: $did, publicKeyHex: $pk, isDefault: true}' \
    > "${STORAGE_DIR}/defaultDid.json"
else
  jq -n --arg did "${selected_did}" \
    '{did: $did, isDefault: true}' \
    > "${STORAGE_DIR}/defaultDid.json"
fi

ok "Default DID set to: ${selected_did}"
echo
echo "${C_DIM}Next: ask your agent to re-check status. Human-Link Status should now read 'Linked'.${C_RST}"
