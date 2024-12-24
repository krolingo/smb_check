#!/bin/bash

# Configuration
SMB_SERVER="DOMAIN OR IP"
SMB_SHARE="*SHARE NAME*"
MOUNT_POINT="/private/tmp/testshare"  # Use /private/tmp/testshare for mounting
LOGFILE="/private/tmp/smb_test.log"
ERRORLOG="/private/tmp/smb_test_error.log"
RESULTFILE="/private/tmp/smb_test_result.log"
USERNAME="*USERNAME*"
PASSWORD="*PASSWORD*"

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
export HOME=/private/tmp

# Function to clean up the mount point directory
cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        echo "Cleaning up mount point $MOUNT_POINT." | /opt/local/bin/doas $TEE -a "$LOGFILE" > /dev/null
        /opt/local/bin/doas $RM -rf "$MOUNT_POINT" 2>>"$ERRORLOG"
    fi
}

# Pre-create or reset log files with doas
/opt/local/bin/doas $TOUCH "$LOGFILE" "$ERRORLOG" "$RESULTFILE"
/opt/local/bin/doas $CHMOD 666 "$LOGFILE" "$ERRORLOG" "$RESULTFILE"

# Clear the log files
echo '' | /opt/local/bin/doas $TEE "$LOGFILE" > /dev/null
echo '' | /opt/local/bin/doas $TEE "$ERRORLOG" > /dev/null
echo '' | /opt/local/bin/doas $TEE "$RESULTFILE" > /dev/null

# Ensure the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    if ! /opt/local/bin/doas $MKDIR -p "$MOUNT_POINT" 2>>"$ERRORLOG"; then
        echo "Failed to create mount point $MOUNT_POINT" | /opt/local/bin/doas $TEE -a "$ERRORLOG" > /dev/null
        echo 1  # Directly print to stdout
        exit 1
    fi
fi

# Check if the mount point is already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Mount point $MOUNT_POINT is already mounted. Attempting to unmount." | /opt/local/bin/doas $TEE -a "$LOGFILE" > /dev/null
    if ! /opt/local/bin/doas $UMOUNT "$MOUNT_POINT" 2>>"$ERRORLOG"; then
        echo "Failed to unmount $MOUNT_POINT. Exiting." | /opt/local/bin/doas $TEE -a "$ERRORLOG" > /dev/null
        echo 1  # Directly print to stdout
        exit 1
    fi
fi

# Ensure the directory is empty
if [ -d "$MOUNT_POINT" ] && [ "$(ls -A "$MOUNT_POINT")" ]; then
    echo "Mount point $MOUNT_POINT is not empty. Cleaning up." | /opt/local/bin/doas $TEE -a "$LOGFILE" > /dev/null
    /opt/local/bin/doas $RM -rf "$MOUNT_POINT"/* 2>>"$ERRORLOG"
fi

# Test SMB mount
if /opt/local/bin/doas $MOUNT_SMBFS //"$USERNAME":"$PASSWORD"@"$SMB_SERVER"/"$SMB_SHARE" "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG"; then
    # Mount succeeded
    echo "SMB Mount Successful: $SMB_SERVER" | /opt/local/bin/doas $TEE -a "$LOGFILE" > /dev/null
    echo 0  # Directly print to stdout
    /opt/local/bin/doas $UMOUNT "$MOUNT_POINT" > /dev/null 2>>"$ERRORLOG"
else
    # Mount failed
    echo "SMB Mount Failed: $SMB_SERVER" | /opt/local/bin/doas $TEE -a "$LOGFILE" > /dev/null
    echo 1  # Directly print to stdout
fi

# Clean up the mount point directory
cleanup

