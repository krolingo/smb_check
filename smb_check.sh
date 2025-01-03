#!/bin/bash

# Configuration
SMB_SERVER="IP_NUMBER"
SMB_SHARE="SHARE_NAME"
MOUNT_POINT="/private/tmp/testshare"
LOGFILE="/tmp/smb_test.log"
ERRORLOG="/tmp/smb_test_error.log"
RESULTFILE="/tmp/smb_test_result.log"
LOCKFILE="/tmp/smb_check.lock"
USERNAME="SMB_USER"
PASSWORD="PASSWORD"

# Ensure a consistent environment
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Locking mechanism to prevent concurrent runs
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "Another instance is running. Exiting." >> "$LOGFILE"
    echo 1
    exit 1
fi

# Function to clear logs
clear_logs() {
    > "$LOGFILE"
    > "$ERRORLOG"
    > "$RESULTFILE"
    echo "[$(date)] Logs cleared." >> "$LOGFILE"
}

# Clear logs at the start of the script
clear_logs

# Function to clean up the mount point directory
cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        echo "Cleaning up mount point $MOUNT_POINT." >> "$LOGFILE"
        sudo umount -f "$MOUNT_POINT" 2>>"$ERRORLOG" || true
        sudo rm -rf "$MOUNT_POINT" 2>>"$ERRORLOG" || true
    fi
    mkdir -p "$MOUNT_POINT" 2>>"$ERRORLOG" || {
        echo "Failed to recreate mount point. Exiting." >> "$LOGFILE"
        echo 1
        exit 1
    }
}

# Log and exit function
log_and_exit() {
    local code=$1
    echo "Exiting with code $code" >> "$LOGFILE"
    echo "$code"
    exit "$code"
}

# Start of script execution
echo "[$(date)] Starting SMB check script" >> "$LOGFILE"
cleanup

# Attempt to mount the SMB share
echo "Attempting to mount SMB share..." >> "$LOGFILE"
if ! sudo mount_smbfs //"$USERNAME":"$PASSWORD"@"$SMB_SERVER"/"$SMB_SHARE" "$MOUNT_POINT" 2>>"$ERRORLOG"; then
    echo "SMB Mount Failed: $SMB_SERVER" >> "$LOGFILE"
    log_and_exit 1
fi

echo "SMB Mount Successful: $SMB_SERVER" >> "$LOGFILE"

# Verify mount operation
if ! mount | grep -q "$MOUNT_POINT"; then
    echo "Mount verification failed." >> "$LOGFILE"
    log_and_exit 1
fi

# Unmount and clean up
echo "Unmounting SMB share..." >> "$LOGFILE"
if ! sudo umount "$MOUNT_POINT" 2>>"$ERRORLOG"; then
    echo "Unmount failed. Attempting forced unmount..." >> "$LOGFILE"
    sudo umount -f "$MOUNT_POINT" 2>>"$ERRORLOG" || {
        echo "Forced unmount failed. Exiting." >> "$LOGFILE"
        log_and_exit 1
    }
fi

cleanup

# Script completed successfully
echo "[$(date)] Script completed successfully." >> "$LOGFILE"
log_and_exit 0
