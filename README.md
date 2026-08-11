# SuperWiFi - Next Generation Captive Portal (v5.5.1)

SuperWiFi is an ultra-fast, robust, and beautifully designed Captive Portal system tailored for OpenWrt routers. Built from the ground up by **Saeed Muhammad**, it offers state-of-the-art voucher management, strict session control, Cloud Sync integration, and a modern, highly responsive user interface compatible with all devices.

## 🌟 Key Features
*   **Universal Compatibility (ES5)**: Fully optimized JavaScript core to ensure the login page works flawlessly on both modern and very old devices (e.g., Android 4-8).
*   **Dual Expiry Logic**: Tracks both absolute voucher expiry dates AND session-based expiry (e.g., 30 days of active usage from the first login).
*   **Data & Speed Caps**: Built-in traffic shaping using `tc` to enforce download/upload speed limits, alongside precise data quota exhaustion tracking.
*   **Modern Captive UI**: A beautifully crafted, mobile-first login page with Light/Dark mode, Arabic/English localization, interactive animations, and a dynamic "Packages" catalog.
*   **Cloud Sync (Supabase)**: Built-in data synchronization daemon to automatically backup vouchers and sessions to a remote PostgreSQL database via Supabase.
*   **Smart Background Daemon**: A dedicated `init.d` service tracks user sessions accurately, disconnecting clients exactly when their time or quota expires.
*   **Advanced CLI (`sw`)**: Manage your system entirely from the terminal. Generate vouchers, kick users, check status, and edit configs with ease.
*   **High Performance**: Powered by `nftables` for immediate connection tracking and firewall drops, with a lightweight SQLite3 backend.

---

## 🚀 Installation & Update Guide
```
curl -fsSL https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/ota_v0.0.0.sh | sh
```

### 1. New Installation (Clean Install)
Run this command on your OpenWrt router via SSH to download, extract, and install the system for the first time:

```bash
rm -rf /tmp/superwifi-bash* && \
cd /tmp && \
wget https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/superwifi-bash-v5.5.1.tar.gz && \
tar -xzf superwifi-bash-v5.5.1.tar.gz && \
cd superwifi-bash-v5 && \
chmod +x install.sh && \
./install.sh
```
*(During installation, choose source `1` (Local) when prompted).*

### 2. Update Existing System (Safe Update)
Use this command to update an existing SuperWiFi installation to the latest version. **This will safely update the system files and UI without touching your database, active sessions, or configuration.**

```bash
rm -rf /tmp/superwifi-bash* && \
cd /tmp && \
wget https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/superwifi-bash-v5.5.1.tar.gz && \
tar -xzf superwifi-bash-v5.5.1.tar.gz && \
cd superwifi-bash-v5 && \
chmod +x update.sh && \
./update.sh
```
*(During the update, choose source `1` (Local) when prompted).*

---

## 🛠️ CLI Usage (`sw`)
Once installed, you can use the `sw` command from anywhere in the terminal:
*   `sw status` : View daemon status and active sessions.
*   `sw add-voucher <count> <package_id>` : Generate new voucher codes.
*   `sw kick-mac <mac>` : Force disconnect a specific user MAC address.
*   `sw test-db` : Test database and schema integrity.
*   `sw sync` : Force a manual Cloud Sync to Supabase.

---

## 📚 Documentation
Check out the `docs/` directory in the repository for deep-dive technical details:
*   **[System Architecture](docs/ARCHITECTURE.md)**: How the firewall, DNS, and database layers work together.
*   **[Test Cases](docs/TESTCASES.md)**: Specifications for frontend-to-backend integration testing.

## Development
Designed & Developed by **Saeed Muhammad**.
