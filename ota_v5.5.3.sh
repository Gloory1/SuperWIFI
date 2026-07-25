#!/bin/sh
echo "Starting OTA Update to v5.5.3..."
rm -rf /tmp/superwifi-bash*
cd /tmp || exit 1
wget -qO superwifi-bash-v5.5.3.tar.gz https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/superwifi-bash-v5.5.3.tar.gz
tar -xzf superwifi-bash-v5.5.3.tar.gz
cd superwifi-bash-v5 || exit 1
chmod +x update.sh
echo "1" | ./update.sh
echo "OTA Update to v5.5.3 completed successfully. Rebooting system to apply changes..."
sleep 2
reboot
