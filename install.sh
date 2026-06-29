#!/bin/sh

# ==============================================================================
# SuperWiFi Automated Installation Script
# Developed by Saeed Muhammad
# ==============================================================================

# ----------------- CONFIGURATION -----------------
# Replace this with the actual raw URL of the repository after you push to GitHub
BASE_RAW="https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/SuperWiFi/main/src"

REQUIRED_PKGS="sqlite3-cli jq nftables tc-tiny"
# -------------------------------------------------

set -e

echo "======================================================"
echo "    🚀 Welcome to SuperWiFi Installation Wizard 🚀   "
echo "======================================================"
echo ""

echo "🔍 [1/6] Checking network connectivity..."
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  echo "❌ Error: No network connection. Please connect to the internet and retry."
  exit 1
fi
echo "✅ Network is OK."

echo ""
echo "🔄 [2/6] Updating package lists..."
opkg update >/dev/null 2>&1 || true

echo "⚙️  Installing required packages ($REQUIRED_PKGS)..."
missing=""
for pkg in $REQUIRED_PKGS; do
  if ! opkg list-installed | awk '{print $1}' | grep -xq "$pkg"; then
    missing="$missing $pkg"
  fi
done

if [ -n "$missing" ]; then
  echo "   -> Installing:$missing"
  opkg install $missing
else
  echo "   -> ✅ All required packages are already installed."
fi

# Verify sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ Error: sqlite3 failed to install. Aborting."
  exit 1
fi

echo ""
echo "📂 [3/6] Preparing directories..."
mkdir -p /usr/lib/superwifi
mkdir -p /usr/sbin
mkdir -p /www/cgi-bin
mkdir -p /www/superwifi
mkdir -p /etc/superwifi
mkdir -p /etc/config
mkdir -p /etc/init.d
mkdir -p /etc/fw4.d
mkdir -p /etc/dnsmasq.d
mkdir -p /var/lib/superwifi
echo "✅ Directories ready."

echo ""
echo "⬇️  [4/6] Downloading system files..."

download() {
  local remote_path="$1"
  local local_path="$2"
  echo "   -> Downloading $(basename "$local_path")..."
  if ! curl -sSLf "$BASE_RAW/$remote_path" -o "$local_path"; then
      echo "      ❌ Failed to download $remote_path using curl, trying wget..."
      if ! wget -qO "$local_path" "$BASE_RAW/$remote_path"; then
          echo "      ❌ Failed to download $remote_path. Ensure the GitHub URL is correct."
          exit 1
      fi
  fi
}

# Core Scripts
download "usr/lib/superwifi/core.sh" "/usr/lib/superwifi/core.sh"
download "usr/lib/superwifi/db.sh" "/usr/lib/superwifi/db.sh"
download "usr/lib/superwifi/fw.sh" "/usr/lib/superwifi/fw.sh"
download "usr/lib/superwifi/tc.sh" "/usr/lib/superwifi/tc.sh"

# CLI & Accounting
download "usr/sbin/sw-cli" "/usr/sbin/sw-cli"
download "usr/sbin/sw-acct.sh" "/usr/sbin/sw-acct.sh"

# Web UI & API
download "www/cgi-bin/auth.sh" "/www/cgi-bin/auth.sh"
download "www/cgi-bin/capport-api.sh" "/www/cgi-bin/capport-api.sh"
download "www/superwifi/login.html" "/www/superwifi/login.html"

# Config & Init
download "etc/config/superwifi" "/etc/config/superwifi"
download "etc/init.d/superwifi" "/etc/init.d/superwifi"
download "etc/fw4.d/99-superwifi.sh" "/etc/fw4.d/99-superwifi.sh"
download "etc/dnsmasq.d/superwifi.conf" "/etc/dnsmasq.d/superwifi.conf"

# Schema & Seed
download "etc/superwifi/superwifi.nft.tpl" "/etc/superwifi/superwifi.nft.tpl"
download "etc/superwifi/schema.sql" "/etc/superwifi/schema.sql"
download "etc/superwifi/vouchers_seed.csv" "/etc/superwifi/vouchers_seed.csv"

echo "🔐 Setting executable permissions..."
chmod +x /usr/lib/superwifi/*.sh
chmod +x /usr/sbin/sw-cli /usr/sbin/sw-acct.sh
chmod +x /www/cgi-bin/*.sh
chmod +x /etc/init.d/superwifi

echo ""
echo "🗄️  [5/6] Initializing Database..."
DB_FILE="/var/lib/superwifi/db.sqlite"

if [ ! -f "$DB_FILE" ]; then
    echo "   -> Creating new database..."
    sqlite3 "$DB_FILE" < /etc/superwifi/schema.sql
    echo "   -> Seeding initial vouchers and packages..."
    sqlite3 -csv "$DB_FILE" ".import /etc/superwifi/vouchers_seed.csv packages" || true
    echo "✅ Database initialized."
else
    echo "   -> Database already exists. Applying schema updates if any..."
    sqlite3 "$DB_FILE" < /etc/superwifi/schema.sql
    echo "✅ Database ready."
fi

echo ""
echo "🚀 [6/6] Activating SuperWiFi Service..."

echo "   -> Reloading firewall..."
fw4 reload || true

echo "   -> Restarting DNS..."
/etc/init.d/dnsmasq restart || true

echo "   -> Enabling and starting SuperWiFi daemon..."
/etc/init.d/superwifi enable
/etc/init.d/superwifi start

echo "======================================================"
echo " 🎉 INSTALLATION COMPLETE! 🎉"
echo "======================================================"
echo " SuperWiFi is now running and managing your network."
echo ""
echo " 🌐 Connect a device to the Wi-Fi."
echo " 📲 The Captive Portal (login page) should appear automatically."
echo " 🛠️  Manage your system via SSH by typing: sw-cli"
echo "======================================================"
