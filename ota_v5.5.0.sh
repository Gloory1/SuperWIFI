#!/bin/sh
# SuperWiFi OTA Update Script for v5.5.0
# This script is executed automatically by sw-sync.sh

echo "Starting OTA Update to v5.5.0..."

# Remove any old temp files
rm -rf /tmp/superwifi-bash*

# Go to temp dir
cd /tmp || exit 1

# Download the new release
wget -qO superwifi-bash-v5.5.0.tar.gz https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/superwifi-bash-v5.5.0.tar.gz

# Extract
tar -xzf superwifi-bash-v5.5.0.tar.gz

# Enter directory
cd superwifi-bash-v5 || exit 1

# Make update script executable
chmod +x update.sh

# Run update script silently, auto-selecting '1' (Local source)
echo "1" | ./update.sh

echo "OTA Update to v5.5.0 completed successfully."
