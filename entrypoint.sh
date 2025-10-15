#!/bin/sh
#
# Samba Entrypoint Script
# Processes environment variables to set up user mapping and passwords,
# then starts the Samba daemon.
# This script uses only pure POSIX shell features for compatibility with /bin/sh.

# --- Configuration ---
USERS_TO_PROCESS="$SMB_USERS"
PASSWORDS_TO_PROCESS="$SMB_PASSWORDS"
USER_MAP_FILE="/etc/samba/usermap.txt"
SHARE_PATH="/srv/samba/share"
SMB_CONF="/etc/samba/smb.conf"

echo "Starting Samba setup..."

# 1. Basic Validation
if [ -z "$USERS_TO_PROCESS" ] || [ -z "$PASSWORDS_TO_PROCESS" ]; then
    echo "Error: SMB_USERS and/or SMB_PASSWORDS environment variables are empty."
    echo "Samba requires at least one user to be set up."
    exit 1
fi

mkdir -p /var/lib/samba/private

# 2. Setup User Mapping and Samba Passwords (Pure POSIX iteration)

# Clear or create the user map file
> "$USER_MAP_FILE"
echo "Generated user map file: $USER_MAP_FILE"

# Save the old IFS and set it to comma for list iteration
OLD_IFS="$IFS"
IFS=','

I=1
# Iterate over the usernames list provided via $SMB_USERS
for CLIENT_NAME_RAW in $USERS_TO_PROCESS; do

    # Remove leading/trailing whitespace from the client name
    CLIENT_NAME=$(echo "$CLIENT_NAME_RAW" | tr -d '[:space:]')

    # Stop if we run out of the 10 pre-created generic users
    if [ "$I" -gt 10 ]; then
        echo "Warning: Too many users provided. Stopping at 10 (samba10)."
        break
    fi

    # 1. Get the current password from the front of the current PASSWORDS string.
    #    Uses ${VAR%%,*} to get everything before the first comma.
    CURRENT_PASS="${PASSWORDS_TO_PROCESS%%,*}"

    if [ -z "$CLIENT_NAME" ]; then
        continue # Skip if the name was just an empty string due to extra commas
    fi

    # Check if we ran out of passwords
    if [ -z "$CURRENT_PASS" ]; then
        echo "Error: User '$CLIENT_NAME' listed, but no corresponding password found."
        exit 1
    fi

    GENERIC_USER="samba${I}"

    echo "Processing user $CLIENT_NAME (internal mapping to $GENERIC_USER)..."

    # A. Add mapping to usermap.txt (Internal Unix User = Client Login Name)
    echo "${GENERIC_USER} = \"${CLIENT_NAME}\"" >> "$USER_MAP_FILE"

    # B. Set the Samba password for the internal generic user.
    #    The password MUST be the one the client (CLIENT_NAME) will use.

    # Use printf to safely pipe the password twice for the add/enable step
    if ! printf '%s\n%s\n' "$CURRENT_PASS" "$CURRENT_PASS" | smbpasswd -a -s "$GENERIC_USER" 2>&1; then
        echo "Error setting Samba password for $GENERIC_USER. Check password complexity."
        # Attempt to enable the user if 'smbpasswd -a' failed
        smbpasswd -e "$GENERIC_USER" 2>/dev/null
    else
        echo "Password set and user enabled for $GENERIC_USER."
    fi

    # 2. Advance the PASSWORDS string for the next iteration.
    #    ${VAR#*,} removes everything up to and including the first comma.

    # Check if the PASSWORDS string still contains a comma
    if echo "$PASSWORDS_TO_PROCESS" | grep -q ','; then
        PASSWORDS_TO_PROCESS="${PASSWORDS_TO_PROCESS#*,}"
    else
        # If no comma left, we processed the last password
        PASSWORDS_TO_PROCESS=""
    fi

    I=$((I + 1))
done

# Restore the original IFS
IFS="$OLD_IFS"

# 3. Final Checks and Execution

echo "User map file content:"
cat "$USER_MAP_FILE"

# Validate smb.conf before starting
if ! testparm -s "$SMB_CONF"; then
    echo "Error: smb.conf validation failed. Check configuration."
    exit 1
fi

echo "Samba initialization complete. Starting daemon..."

# Execute smbd in foreground mode (-F) with no daemonization (-S) to keep the container alive
# The 'exec' command replaces the shell process with the smbd process
exec /usr/sbin/smbd -F --debug-stdout -d 1 --no-process-group
