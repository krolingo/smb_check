#!/bin/bash

# Configuration
SMB_SERVER=""
SMB_SHARE=""
MOUNT_POINT="/var/tmp/testshare"  # Changed to /var/tmp for better reliability
LOGFILE="/var/tmp/smb_test.log"
ERRORLOG="/var/tmp/smb_test_error.log"
RESULTFILE="/var/tmp/smb_test_result.log"
USERNAME="samba_check"
PASSWORD=""

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
        $UMOUNT "$MOUNT_POINT" 2>>"$ERRORLOG"
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

# Pre-create or reset log files
$TOUCH "$LOGFILE" "$ERRORLOG" "$RESULTFILE"
$CHMOD 666 "$LOGFILE" "$ERRORLOG" "$RESULTFILE"

# Clear the log files
echo '' | $TEE "$LOGFILE" > /dev/null
echo '' | $TEE "$ERRORLOG" > /dev/null
echo '' | $TEE "$RESULTFILE" > /dev/null

# Ensure the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    if ! $MKDIR -p "$MOUNT_POINT" 2>>"$ERRORLOG"; then
        log_and_exit "Failed to create mount point $MOUNT_POINT" 1
    fi
fi

# Check if the mount point is already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Mount point $MOUNT_POINT is already mounted. Attempting to unmount." | $TEE -a "$LOGFILE" > /dev/null
    if ! $UMOUNT "$MOUNT_POINT" 2>>"$ERRORLOG"; then
        log_and_exit "Failed to unmount $MOUNT_POINT" 1
    fi
fi

# Ensure the directory is empty
if [ -d "$MOUNT_POINT" ] && [ "$(ls -A "$MOUNT_POINT")" ]; then
    echo "Mount point $MOUNT_POINT is not empty. Cleaning up." | $TEE -a "$LOGFILE" > /dev/null
    $RM -rf "$MOUNT_POINT"/* 2>>"$ERRORLOG"
fi

# Test SMB mount
if $MOUNT_SMBFS //"$USERNAME":"$PASSWORD"@"$SMB_SERVER"/"$SMB_SHARE" "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG"; then
    # Mount succeeded
    echo "SMB Mount Successful: $SMB_SERVER" | $TEE -a "$LOGFILE" > /dev/null
    echo 0  # Output success code
    $UMOUNT "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG"
else
    # Mount failed
    log_and_exit "SMB Mount Failed: $SMB_SERVER" 1
fi

# Clean up the mount point directory
cleanup

# Final success output
exit 0
