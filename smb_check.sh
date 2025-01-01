#!/bin/bash

# Configuration
SMB_SERVER="IP OR HOSTNAME"
SMB_SHARE="SHARE"
MOUNT_POINT="/var/tmp/testshare"  # Changed to /var/tmp for better reliability
LOGFILE="/var/tmp/smb_test.log"
ERRORLOG="/var/tmp/smb_test_error.log"
RESULTFILE="/var/tmp/smb_test_result.log"
USERNAME="USER"
PASSWORD="PASSWORD"
LOCKFILE="/var/tmp/smb_check.lock"

# Paths to commands
TOUCH="/usr/bin/touch"
CHMOD="/bin/chmod"
TEE="/usr/bin/tee"
MKDIR="/bin/mkdir"
RM="/bin/rm"
MOUNT_SMBFS="/sbin/mount_smbfs"
UMOUNT="/sbin/umount"

# Sanitize environment
export PATH=/usr/local/opt/ruby/bin:/usr/local/sbin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
export HOME=/var/tmp  # Changed to avoid conflicts with /private/tmp

# Function to clean up the mount point directory
cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        echo "Cleaning up mount point $MOUNT_POINT." | $TEE -a "$LOGFILE" > /dev/null
        $UMOUNT -f "$MOUNT_POINT" >> "$LOGFILE" 2>>"$ERRORLOG"
        $RM -rf "$MOUNT_POINT" 2>>"$ERRORLOG"
    fi
}

# Function to log and exit with error code
log_and_exit() {
    local message="$1"
    local code="$2"
    echo "$message" | $TEE -a "$ERRORLOG" > /dev/null
    echo "$code"  # Output the error code for Zabbix
    exit "$code"
}

# Ensure no concurrent runs
exec 200>"$LOCKFILE"
flock -n 200 || log_and_exit "Another instance is running" 1

# Pre-create or reset log files
$TOUCH "$LOGFILE" "$ERRORLOG" "$RESULTFILE"
$CHMOD 666 "$LOGFILE" "$ERRORLOG" "$RESULTFILE"

# Clear the log files
echo '' | $TEE "$LOGFILE" > /dev/null
echo '' | $TEE "$ERRORLOG" > /dev/null
echo '' > "$RESULTFILE"  # Do not output to stdout

# Log script execution context
echo "Script executed at $(date) by $(whoami)" | $TEE -a "$LOGFILE" > /dev/null
env | $TEE -a "$LOGFILE" > /dev/null

# Ensure the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    if ! $MKDIR -p "$MOUNT_POINT" 2>>"$ERRORLOG"; then
        log_and_exit "Failed to create mount point $MOUNT_POINT" 1
    fi
fi

# Check if the mount point is already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Stale mount detected. Unmounting." | $TEE -a "$LOGFILE"
    $UMOUNT -f "$MOUNT_POINT" >> "$LOGFILE" 2>>"$ERRORLOG"
fi

# Ensure the directory is empty
if [ -d "$MOUNT_POINT" ] && [ "$(ls -A "$MOUNT_POINT")" ]; then
    echo "Mount point $MOUNT_POINT is not empty. Cleaning up." | $TEE -a "$LOGFILE" > /dev/null
    $RM -rf "$MOUNT_POINT"/* 2>>"$ERRORLOG"
    sleep 1  # Allow time for the filesystem to sync
fi

# Test SMB mount
MAX_RETRIES=3
RETRY_COUNT=0
while ! $MOUNT_SMBFS //"$USERNAME":"$PASSWORD"@"$SMB_SERVER"/"$SMB_SHARE" "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG" && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Retrying SMB mount ($RETRY_COUNT/$MAX_RETRIES)" | $TEE -a "$LOGFILE"
    sleep 2
done
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_and_exit "SMB Mount Failed after $MAX_RETRIES retries" 1
fi

# Mount succeeded
echo "SMB Mount Successful: $SMB_SERVER" | $TEE -a "$LOGFILE" > /dev/null
echo 0 > "$RESULTFILE"  # Write success to result file

# Unmount and clean up
$UMOUNT "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG"
cleanup

# Final success output
echo 0
exit 0
