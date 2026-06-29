# SuperWiFi - Next Generation Captive Portal

SuperWiFi is an ultra-fast, robust, and beautifully designed Captive Portal system tailored for OpenWrt routers. Built from the ground up by Saeed Muhammad, it offers state-of-the-art voucher management, strict session control, and a modern, responsive user interface.

## Features 🌟
*   **Dual Expiry Logic**: Tracks both absolute voucher expiry dates AND session-based expiry (e.g., 30 days of active usage from the first login).
*   **Data & Speed Caps**: Built-in traffic shaping using `tc` to enforce download/upload speed limits, alongside precise data quota exhaustion tracking.
*   **Modern Captive UI**: A beautifully crafted, mobile-first login page with Light/Dark mode, Arabic/English localization, and a "Packages" catalog.
*   **Smart Background Daemon**: A dedicated `init.d` and `sw-acct.sh` background service tracks user sessions accurately, disconnecting clients exactly when their time or quota expires.
*   **Advanced CLI (`sw-cli`)**: Manage your system entirely from the terminal. Generate vouchers, kick users, check status, and edit configs with ease.
*   **High Performance**: Powered by `nftables` for immediate connection tracking and firewall drops, with a lightweight SQLite3 backend.

## 🚀 Quick Installation

Run this single command on your OpenWrt router via SSH to install the entire system:

```bash
wget -qO- https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/SuperWiFi/main/install.sh | sh
```

*(Note: Change the URL above to match your actual GitHub repository URL once pushed).*

## 📚 Documentation
Check out the `docs/` directory for deep-dive technical details:
*   **[System Architecture](docs/architecture.md)**: How the firewall, DNS, and database layers work together.
*   **[API Guide](docs/api_guide.md)**: Specifications for the frontend-to-backend communication.
*   **[Cron Jobs & Daemon](docs/cron_jobs.md)**: How session accounting operates in the background.

## 🛠️ CLI Usage (`sw-cli`)
Once installed, you can use the `sw-cli` command:
*   `sw-cli status`: View daemon status and active sessions.
*   `sw-cli generate <count> [package_id]`: Generate new voucher codes.
*   `sw-cli print-vouchers`: Print all available (unused) vouchers.
*   `sw-cli disconnect <mac>`: Force disconnect a user.
*   `sw-cli db-shell`: Open the SQLite database interactively.

## Development
Designed by **Saeed Muhammad**.
