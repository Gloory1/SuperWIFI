#!/bin/sh
echo "Starting OTA Update to v5.5.6..."
rm -rf /tmp/superwifi-bash*
cd /tmp || exit 1
wget -O superwifi-bash-v5.5.6.tar.gz https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/superwifi-bash-v5.5.6.tar.gz
if [ ! -f superwifi-bash-v5.5.6.tar.gz ]; then
    echo "ERROR: Failed to download tarball!"
    exit 1
fi
tar -xzf superwifi-bash-v5.5.6.tar.gz
cd superwifi-bash-v5 || exit 1
chmod +x update.sh
echo "1" | ./update.sh
echo "OTA Update to v5.5.6 completed successfully. Rebooting system to apply changes..."
sleep 2
reboot
