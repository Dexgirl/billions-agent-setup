#!/usr/bin/env bash
# billions-upgrade-safely.sh
# Safely upgrade the verified-agent-identity skill without losing your linked default DID.
# Works around https://github.com/BillionsNetwork/verified-agent-identity/issues/571
#
# Usage:
#   ./billions-upgrade-safely.sh
#
# What it does:
#   1. Snapshots defaultDid.json and identities.json to a timestamped backup dir
#   2. Runs `npx clawhub@latest install verified-agent-identity`
#   3. Compares post-install default DID against the snapshot
#   4. Auto-restores if v1.0.4 silently flipped your default
#   5. Reports final state

set -euo pipefail

STORAGE_DIR="${HOME}/.openclaw/billions"
BACKUP_ROOT="${STORAGE_DIR}/upgrade-log"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/${TS}"

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_DIM=""; C_RST=""
fi

log()  { echo "${C_DIM}[$(date -u +%H:%M:%SZ)]${C_RST} $*"; }
ok()   { echo "${C_GRN}✓${C_RST} $*"; }
warn() { echo "${C_YLW}⚠${C_RST} $*"; }
err()  { echo "${C_RED}✗${C_RST} $*" >&2; }

if [[ ! -d "${STORAGE_DIR}" ]]; then
  err "Storage directory not found: ${STORAGE_DIR}"
  err "Is the verified-agent-identity skill installed for this user?"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required. Install with: sudo apt install jq"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  err "npx is required. Install Node.js first."
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
log "Backup dir: ${BACKUP_DIR}"

log "Snapshotting current state..."
for f in defaultDid.json identities.json kms.json; do
  if [[ -f "${STORAGE_DIR}/${f}" ]]; then
    cp "${STORAGE_DIR}/${f}" "${BACKUP_DIR}/${f}"
    ok "Backed up ${f}"
  else
    warn "${f} not found (may be normal for fresh installs)"
  fi
done

PRE_DEFAULT=""
if [[ -f "${BACKUP_DIR}/defaultDid.json" ]]; then
  PRE_DEFAULT="$(jq -r '.did // empty' "${BACKUP_DIR}/defaultDid.json")"
fi

if [[ -n "${PRE_DEFAULT}" ]]; then
  log "Pre-upgrade default DID: ${PRE_DEFAULT}"
else
  warn "No existing default DID found — nothing to protect."
fi

echo
log "Running: npx clawhub@latest install verified-agent-identity"
echo "${C_DIM}─────────────────────────────────────────────${C_RST}"
npx clawhub@latest install verified-agent-identity
echo "${C_DIM}─────────────────────────────────────────────${C_RST}"
ok "Skill install command completed."
echo

POST_DEFAULT=""
if [[ -f "${STORAGE_DIR}/defaultDid.json" ]]; then
  POST_DEFAULT="$(jq -r '.did // empty' "${STORAGE_DIR}/defaultDid.json")"
fi

log "Post-upgrade default DID: ${POST_DEFAULT:-<none>}"

if [[ -z "${PRE_DEFAULT}" ]]; then
  ok "No prior default — nothing to restore."
  exit 0
fi

if [[ "${PRE_DEFAULT}" == "${POST_DEFAULT}" ]]; then
  ok "Default DID preserved. No action needed."
  exit 0
fi

warn "Default DID was overridden by the upgrade."
warn "  Was:  ${PRE_DEFAULT}"
warn "  Now:  ${POST_DEFAULT}"
warn "Restoring previous default..."

if [[ -f "${STORAGE_DIR}/identities.json" ]]; then
  if ! jq -e --arg d "${PRE_DEFAULT}" 'any(.[]; .did == $d)' "${STORAGE_DIR}/identities.json" >/dev/null; then
    err "Previous default DID is no longer in identities.json — cannot auto-restore."
    err "Backup retained at: ${BACKUP_DIR}"
    err "Restore manually with: ./restore-default-did.sh"
    exit 2
  fi
fi

cp "${BACKUP_DIR}/defaultDid.json" "${STORAGE_DIR}/defaultDid.json"
ok "Restored ${STORAGE_DIR}/defaultDid.json from snapshot."

FINAL_DEFAULT="$(jq -r '.did // empty' "${STORAGE_DIR}/defaultDid.json")"
if [[ "${FINAL_DEFAULT}" == "${PRE_DEFAULT}" ]]; then
  ok "Final default DID: ${FINAL_DEFAULT}"
  echo
  ok "${C_GRN}Upgrade complete. Linked DID preserved. FAIAR eligibility intact.${C_RST}"
  echo
  log "The orphan DID (${POST_DEFAULT}) is still in identities.json. Leave it; it's harmless."
  log "Backup retained at: ${BACKUP_DIR}"
else
  err "Restore failed — final default does not match snapshot."
  err "Inspect manually: ${STORAGE_DIR}/defaultDid.json"
  exit 3
fi
