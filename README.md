
# SMB Monitoring Script for Zabbix

This script mounts and unmounts the specified SMB share to ensure it is accessible, reporting the status to Zabbix. It is tailored for integration with Zabbix monitoring systems and includes robust error handling, detailed logging, and a lock mechanism to prevent concurrent executions.

## Features

- **SMB Share Monitoring**: Verifies if an SMB share can be successfully mounted and unmounted.
- **Zabbix Integration**: Outputs status codes (`0` for success, `1` for failure) for integration with Zabbix items.
- **Error Handling**: Handles busy mount points, stale processes, and unexpected errors gracefully.
- **Logging**: Generates detailed logs for troubleshooting, including timestamps and descriptions of each step.
- **Environment Standardization**: Ensures consistent execution, even in restricted environments like Zabbix.

## Prerequisites

- **Operating System**: Tested on macOS (should work on Unix-like systems with minor adjustments).
- **Dependencies**:
  - `sudo` or `doas` for privilege elevation.
  - SMB client tools (`mount_smbfs`, `umount`).
  - Standard utilities: `flock`, `mkdir`, `rm`, `lsof`, `fuser`.

## Configuration

Update the following variables in the script to match your environment:

- `SMB_SERVER`: The IP or hostname of the SMB server.
- `SMB_SHARE`: The name of the SMB share.
- `MOUNT_POINT`: Directory where the SMB share will be mounted.
- `USERNAME` and `PASSWORD`: Credentials for accessing the SMB share.

Example:
```bash
SMB_SERVER="192.168.1.100"
SMB_SHARE="Bucket"
MOUNT_POINT="/private/tmp/testshare"
USERNAME="samba_checker_user"
PASSWORD="your_password_here"
```

## Installation

1. Copy the script to your Zabbix external scripts directory (e.g., `/usr/local/share/zabbix/externalscripts/`).
2. Ensure the script is executable:
   ```bash
   chmod +x /usr/local/share/zabbix/externalscripts/smb_check.sh
   ```
3. Configure `sudo` permissions for the Zabbix user:
   - Edit `/etc/sudoers.d/zabbix`:
     ```plaintext
     zabbix ALL=(ALL) NOPASSWD: /sbin/mount_smbfs, /sbin/umount, /bin/rm, /bin/mkdir, /usr/bin/lsof, /usr/bin/fuser
     ```

## Usage

### Manual Execution
Run the script manually to verify functionality:
```bash
sudo -u zabbix /bin/bash /usr/local/share/zabbix/externalscripts/smb_check.sh
```

### Integration with Zabbix
1. Create a Zabbix item:
   - **Type**: External check
   - **Key**: `smb_check.sh`
2. Set up a trigger to alert if the script fails (`value = 1`).

### Logs
- Execution logs: `/tmp/smb_test.log`
- Error logs: `/tmp/smb_test_error.log`

### Script Behavior

1. Ensures no concurrent executions using a `flock`-based lock file.
2. Cleans up stale mount points and creates the mount directory if necessary.
3. Attempts to mount the SMB share.
4. Verifies the mount operation and logs success or failure.
5. Unmounts the share and cleans up the mount point.

## Troubleshooting

- If the script fails to execute:
  - Check the logs in `/tmp/smb_test.log` and `/tmp/smb_test_error.log`.
  - Ensure the Zabbix user has the required `sudo` permissions.
  - Test individual commands (e.g., `sudo mount_smbfs`) manually.

## Limitations

- Designed for environments where the Zabbix user has `sudo` access to specific commands.
- Assumes `mount_smbfs` is available. Adjustments may be needed for other SMB clients.

## Contributions

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request.

## License

This script is licensed under the MIT License.
