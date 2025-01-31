import subprocess
import os
import datetime
import argparse
import shutil  # For copying files (alternative to restic for local backups if needed)
import psutil # For checking if PCSX2 is running

def log_message(message, log_file):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message_str = f"{timestamp}: {message}"
    with open(log_file, "a") as f:
        f.write(log_message_str + "\n")
    print(log_message_str)

def sync_memcards(memcard_dir, restic_repo, restic_password, log_file):
    log_message("Syncing memory cards with restic...", log_file)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    restic_cmd = f"restic -r \"{restic_repo}\" -p \"{restic_password}\" backup \"{memcard_dir}\" --tag \"{timestamp}\""
    try:
        subprocess.run(restic_cmd, shell=True, check=True)
        log_message(f"Memory cards backed up successfully (snapshot: {timestamp}).", log_file)
        restic_forget_cmd = f"restic -r \"{restic_repo}\" -p \"{restic_password}\" forget --keep-daily 7"
        subprocess.run(restic_forget_cmd, shell=True, check=True) # Prune old snapshots
    except subprocess.CalledProcessError as e:
        log_message(f"Error backing up memory cards: {e}", log_file)
        exit(1)

def restore_memcards(memcard_dir, restic_repo, restic_password, log_file):
    log_message("Restoring memory cards from restic...", log_file)
    restic_snapshots_cmd = f"restic -r \"{restic_repo}\" -p \"{restic_password}\" snapshots --latest"
    try:
        latest_snapshot = subprocess.check_output(restic_snapshots_cmd, shell=True, text=True).strip()
        if latest_snapshot:
            restic_restore_cmd = f"restic -r \"{restic_repo}\" -p \"{restic_password}\" restore \"{latest_snapshot}\" --target \"{memcard_dir}\" --exclude \"{memcard_dir}/.locks/*\" --force"
            subprocess.run(restic_restore_cmd, shell=True, check=True)
            log_message(f"Memory cards restored successfully from snapshot {latest_snapshot}.", log_file)
        else:
            log_message("No snapshots found in the repository.", log_file)
            exit(1)
    except subprocess.CalledProcessError as e:
        log_message(f"Error restoring memory cards: {e}", log_file)
        exit(1)

def is_pcsx2_running(pcsx2_exe):
    for process in psutil.process_iter(['name']):
        if process.info()['name'] == pcsx2_exe:
            return True
    return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sync/Restore PCSX2 memory cards.")
    parser.add_argument("-r", "--repo", required=True, help="Path to the restic repository.")
    parser.add_argument("-p", "--password", required=True, help="Password for the restic repository.")
    parser.add_argument("-m", "--memcard-dir", default=os.path.expanduser("~/.config/PCSX2/memcards"), help="Path to the PCSX2 memcard directory (default: ~/.config/PCSX2/memcards).")
    parser.add_argument("--restore", action="store_true", help="Restore memory cards from the latest snapshot.")
    parser.add_argument("pcsx2_exe", nargs="?", default="pcsx2", help="Name of the PCSX2 executable (default: pcsx2).") # Add pcsx2_exe argument
    args = parser.parse_args()


    log_file = os.path.expanduser("~/pcsx2_sync.log")  # Log file in home directory

    RESTIC_CMD = f"restic -r \"{args.repo}\" -p \"{args.password}\"" # Construct restic command
    PCSX2_EXE = args.pcsx2_exe # Get pcsx2 exe name

    if args.restore:
        restore_memcards(args.memcard_dir, args.repo, args.password, log_file)
    elif is_pcsx2_running(PCSX2_EXE):
        log_message(f"{PCSX2_EXE} is currently running. Skipping pre-game sync.", log_file)
    else:
        sync_memcards(args.memcard_dir, args.repo, args.password, log_file)

    try:
        subprocess.run([PCSX2_EXE], check=True) # Run PCSX2. Pass arguments if needed.
        pcsx2_exit_code = 0 # Assume 0 if no exception
        log_message(f"{PCSX2_EXE} exited with code {pcsx2_exit_code}.", log_file)
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to launch {PCSX2_EXE}: {e}", log_file)
        exit(1)
    except FileNotFoundError: # Handle if pcsx2 isn't found
        log_message(f"Failed to launch {PCSX2_EXE}: File not found", log_file)
        exit(1)

    if not args.restore:
        sync_memcards(args.memcard_dir, args.repo, args.password, log_file)

    log_message("Script finished.", log_file)
