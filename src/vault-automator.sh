#!/bin/bash
set -uo pipefail

# Path to save unseal keys and root token
declare UNSEAL_FILE="${UNSEAL_FILE:-/unseal/vault_unseal_keys.json}"

# Number of shares to split the unseal keys into
declare VAULT_SHARES="${VAULT_SHARES:-1}"

# Threshold number of keys required to unseal
declare VAULT_THRESHOLD="${VAULT_THRESHOLD:-1}"

# Poll interval in seconds
declare POLL_INTERVAL="${POLL_INTERVAL:-5}"

# Timeout for vault status command
declare TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"

# Vault status variables
declare VAULT_REACHABLE=false
declare VAULT_INITIALIZED=false
declare VAULT_SEALED=true

# Logging function with timestamp
log() { printf '[%(%Y-%m-%dT%H:%M:%S%z)T] %s\n' -1 "$*"; }

# Update the status of the Vault server
update_status() {
  # Defaults
  VAULT_REACHABLE=false
  VAULT_INITIALIZED=false
  VAULT_SEALED=true

  # Use a short timeout so we don't hang if DNS or TCP stalls
  # Also pass VAULT_ADDR explicitly if you want to be sure
  local vault_status
  vault_status="$(timeout "${TIMEOUT_SECONDS}s" vault status -format=json 2>/dev/null)"
  local exit_code=$?

  # Treat only 0 (unsealed) and 2 (sealed) as "reachable"
  if [[ "$exit_code" -eq 0 || "$exit_code" -eq 2 ]]; then
    # Sanity-check that we actually got JSON; otherwise mark unreachable
    if jq -e . >/dev/null 2>&1 <<<"$vault_status"; then
      VAULT_REACHABLE=true
      VAULT_INITIALIZED="$(jq -r '.initialized' <<<"$vault_status")"
      VAULT_SEALED="$(jq -r '.sealed' <<<"$vault_status")"
    else
      log "Got non-JSON from vault status despite exit $exit_code; marking unreachable."
      VAULT_REACHABLE=false
    fi
  else
    # exit_code==1 or anything unexpected => unreachable/error
    VAULT_REACHABLE=false
  fi
}

# Save the initialization JSON output to the unseal file
save_init_json() {
  local payload="$1"
  (
    umask 077
    mkdir -p "$(dirname "$UNSEAL_FILE")"
    printf '%s\n' "$payload" > "$UNSEAL_FILE"
  )
  log "Unseal keys and root token saved to $UNSEAL_FILE"
}

# Initialize the Vault server
initialize_vault() {
  log "Initializing Vault with $VAULT_SHARES shares and $VAULT_THRESHOLD threshold..."
  local init_output=$(vault operator init -key-shares="$VAULT_SHARES" -key-threshold="$VAULT_THRESHOLD" -format=json)
  local exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    log "Vault initialization failed."
    return 1
  fi

  save_init_json "$init_output"
  sleep 1
  update_status
  if [[ "$VAULT_INITIALIZED" == true ]]; then
    log "Vault is now initialized."
    return 0
  fi

  log "Failed to initialize Vault."
  return 1
}

# Unseal the Vault server
unseal_vault() {
  if [ ! -f "$UNSEAL_FILE" ]; then
    log "Unseal file $UNSEAL_FILE not found!"
    return 1
  fi

  log "Unsealing Vault using keys from $UNSEAL_FILE"
  for key in $(jq -r '.unseal_keys_b64[]' "$UNSEAL_FILE"); do
    vault operator unseal "$key" >/dev/null 2>&1 || true
    sleep 1
    update_status
    if [[ "$VAULT_SEALED" == false ]]; then
      log "Vault is now unsealed."
      return 0
    fi
  done

  log "Failed to unseal Vault with provided keys."
  return 1
}

# Main loop
declare FIRST_RUN=true
declare ALREADY_UNSEALED=false
declare VAULT_REACHABLE_AGAIN=true
declare STOP=false

# Handle termination signals
trap 'STOP=true' TERM INT

# Initial logging
log "Starting Vault Automator..."
log "Vault Address: ${VAULT_ADDR:-<not set>}"
log "Unseal File: $UNSEAL_FILE"
log "Vault Shares: $VAULT_SHARES"
log "Vault Threshold: $VAULT_THRESHOLD"

while [[ "$STOP" == false ]]; do
  update_status

  if [[ "$VAULT_REACHABLE" == false ]]; then
    log "Vault is not reachable at ${VAULT_ADDR:-<not set>}. Retrying..."
    # Allow the first run message to show again when Vault becomes reachable
    VAULT_REACHABLE_AGAIN=false
    FIRST_RUN=true
  fi
  
  if [[ "$VAULT_REACHABLE" == true && "$VAULT_REACHABLE_AGAIN" == false ]]; then
    log "Vault is now reachable at ${VAULT_ADDR:-<not set>}."
    VAULT_REACHABLE_AGAIN=true
  fi

  if [[ "$FIRST_RUN" == true && "$VAULT_INITIALIZED" == true && "$VAULT_SEALED" == false ]]; then
      log "Vault is already initialized and unsealed."
  fi

  if [[ "$VAULT_REACHABLE" == true && "$VAULT_INITIALIZED" == false ]]; then
    initialize_vault
  fi

  if [[ "$VAULT_REACHABLE" == true && "$VAULT_INITIALIZED" == true && "$VAULT_SEALED" == true ]]; then
    unseal_vault
  fi
  
  FIRST_RUN=false
  sleep "$POLL_INTERVAL" & wait $! 2>/dev/null || true
done

log "Stopping Vault Automator"
exit 0