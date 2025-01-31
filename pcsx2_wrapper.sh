#!/bin/bash

set -ue

# --- Configuration ---
MEMCARD_DIR="$HOME/.config/PCSX2/memcards"  # Adjust if different
PCSX2_EXE="pcsx2" # or pcsx2-qt, etc.
LOG_FILE="$HOME/pcsx2_sync.log"

# --- Restic Configuration ---
RESTIC_REPO="$HOME/pcsx2_backups_repo"  # Path to your restic repository (can be local or cloud-based)
RESTIC_PASSWORD="your_restic_password" # VERY IMPORTANT: Set a strong password!
RESTIC_CMD="restic -r \"$RESTIC_REPO\" -p \"$RESTIC_PASSWORD\""


# --- Functions ---

log_message() {
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  message="$timestamp: $*"
  echo "$message" >> "$LOG_FILE"
  echo "$message"
}

sync_memcards() {
  log_message "Syncing memory cards with restic..."
  snapshot_tag=$(date +"%Y%m%d_%H%M%S")
  if eval "$RESTIC_CMD backup \"$MEMCARD_DIR\" --tag \"$snapshot_tag\""; then
    log_message "Memory cards backed up successfully (snapshot: $snapshot_tag)."
    # Optional: Prune old snapshots (adjust as needed)
    eval "$RESTIC_CMD forget --keep-daily 7" # Example: Keep last 7 daily snapshots
  else
    log_message "Error backing up memory cards with restic. Check the logs and your restic setup."
    exit 1
  fi
}

# --- Main Script ---

if pgrep -x "$PCSX2_EXE" > /dev/null; then
  log_message "$PCSX2 is currently running. Skipping pre-game sync."
else
  sync_memcards
fi

if eval "$PCSX2_EXE" "$@"; then
  pcsx2_exit_code=$?
  log_message "$PCSX2 exited with code $pcsx2_exit_code."
else
  log_message "Failed to launch PCSX2."
  exit 1
fi

sync_memcards

log_message "Script finished."

exit 0
