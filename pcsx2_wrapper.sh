#!/bin/bash
set -eu

# --- Configuration ---
MEMCARD_DIR="$HOME/.config/PCSX2/memcards"  # Default memcard directory
PCSX2_EXE="pcsx2" # or pcsx2-qt, etc.
LOG_FILE="$HOME/pcsx2_sync.log"

# --- Restic Configuration ---
RESTIC_REPO=""  # Required, will be set via command-line
RESTIC_PASSWORD="" # Required, will be set via command-line
RESTIC_CMD="" # Will be constructed later

# --- Help String ---
HELP_STRING=$(cat <<EOF
Usage: $0 [options]

This script syncs PCSX2 memory cards to a cloud storage using restic.

Options:
  -h, --help      Show this help message and exit.
  -r <repo>, --repo <repo>    Path to the restic repository. (Required)
  -p <password>, --password <password>  Password for the restic repository. (Required)
    -m <dir>, --memcard-dir <dir>  Path to the PCSX2 memcard directory. (Optional, defaults to ~/.config/PCSX2/memcards)

Examples:
  $0 -r /path/to/repo -p mysecretpassword
  $0 --repo sftp://user@host/repo --password mysecretpassword -m /path/to/memcards

EOF
)

# --- Functions ---

log_message() {
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  message="$timestamp: $*"
  echo "$message" >> "$LOG_FILE"
  echo "$message"
}

show_help() {
  echo "$HELP_STRING"
  exit 0
}

sync_memcards() {
  log_message "Syncing memory cards with restic..."
  snapshot_tag=$(date +"%Y%m%d_%H%M%S")
  if eval "$RESTIC_CMD backup \"$MEMCARD_DIR\" --tag \"$snapshot_tag\""; then
    log_message "Memory cards backed up successfully (snapshot: $snapshot_tag)."
    eval "$RESTIC_CMD forget --keep-daily 7" # Optional: Prune old snapshots
  else
    log_message "Error backing up memory cards with restic. Check the logs and your restic setup."
    exit 1
  fi
}


# --- Parse Command-Line Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -r|--repo)
      RESTIC_REPO="$2"
      shift 2
      ;;
    -p|--password)
      RESTIC_PASSWORD="$2"
      shift 2
      ;;
        -m|--memcard-dir)
      MEMCARD_DIR="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      show_help
      ;;
  esac
done


# --- Check for Required Arguments ---
if [[ -z "$RESTIC_REPO" || -z "$RESTIC_PASSWORD" ]]; then
  echo "Error: Both -r/--repo and -p/--password are required." >&2
  show_help
fi

# --- Construct restic command ---
RESTIC_CMD="restic -r \"$RESTIC_REPO\" -p \"$RESTIC_PASSWORD\""


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
