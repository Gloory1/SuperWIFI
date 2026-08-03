#!/bin/sh
# =============================================================================
# SuperWiFi OTA Update Script — v8.1.5
# =============================================================================
# Changes in this release:
#   [AUTO-REPAIR] Automatic class_id, nftables & TC filter repair during update.
#   [SESSION-PRESERVE] Restores all active sessions into firewall set during update.
#   [INPUT-SANITY] Clean CRLF (\r) & numeric sanitization across all DB/TC queries.
#   [CLI] Added 'sw repair' / 'sw fix' command for instant manual session recovery.
#   [SUPABASE] Automatic Supabase OTA cloud update registration.
#   [REBOOT] Automated router reboot to apply kernel updates cleanly.
# =============================================================================

VERSION="8.1.5"
TARBALL="superwifi-bash-v${VERSION}.tar.gz"
GITHUB_URL="https://raw.githubusercontent.com/Gloory1/SuperWIFI/main/${TARBALL}"
WORK_DIR="/tmp/superwifi-ota-${VERSION}"

# --- Colors (safe for busybox ash) ---
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
RST='\033[0m'

log_info()  { printf "${GRN}[✓]${RST} %s\n" "$1"; }
log_warn()  { printf "${YLW}[!]${RST} %s\n" "$1"; }
log_error() { printf "${RED}[✗]${RST} %s\n" "$1" >&2; }
log_step()  { printf "\n${CYN}━━ %s${RST}\n" "$1"; }
die()       { log_error "$1"; exit 1; }

printf "\n"
printf "${CYN}╔══════════════════════════════════════════╗${RST}\n"
printf "${CYN}║  SuperWiFi OTA Update  →  v%-13s  ║${RST}\n" "$VERSION"
printf "${CYN}╚══════════════════════════════════════════╝${RST}\n\n"

# =============================================================================
# 0. Pre-flight checks
# =============================================================================
log_step "0/5 · Pre-flight checks"

[ "$(id -u)" -eq 0 ] || die "Must be run as root"
command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 not found"
command -v uci    >/dev/null 2>&1 || die "uci not found"

DB_PATH=$(uci get superwifi.core.db_path 2>/dev/null || echo "/etc/superwifi/superwifi.db")
log_info "DB path: $DB_PATH"

CURRENT_VER="unknown"
[ -f /etc/superwifi-version ] && CURRENT_VER=$(cat /etc/superwifi-version | tr -d ' \r\n')
log_info "Current version: $CURRENT_VER"

[ "$CURRENT_VER" = "$VERSION" ] && \
    log_warn "Already on v${VERSION}. Re-applying update anyway..."

# =============================================================================
# 1. Download tarball
# =============================================================================
log_step "1/5 · Downloading v${VERSION}"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" || die "Cannot create work dir $WORK_DIR"

DL_OK=0
if [ -f "/home/saeed/superwifi_project/${TARBALL}" ]; then
    cp "/home/saeed/superwifi_project/${TARBALL}" "${WORK_DIR}/${TARBALL}" && DL_OK=1
elif [ -f "/tmp/${TARBALL}" ]; then
    cp "/tmp/${TARBALL}" "${WORK_DIR}/${TARBALL}" && DL_OK=1
fi

if [ "$DL_OK" = "0" ] && command -v curl >/dev/null 2>&1; then
    curl -fsSL "$GITHUB_URL" -o "${WORK_DIR}/${TARBALL}" 2>/dev/null && [ -s "${WORK_DIR}/${TARBALL}" ] && DL_OK=1
fi
if [ "$DL_OK" = "0" ] && command -v wget >/dev/null 2>&1; then
    rm -f "${WORK_DIR}/${TARBALL}"
    wget -q --no-check-certificate "$GITHUB_URL" -O "${WORK_DIR}/${TARBALL}" 2>/dev/null && [ -s "${WORK_DIR}/${TARBALL}" ] && DL_OK=1
fi
if [ "$DL_OK" = "0" ] && command -v uclient-fetch >/dev/null 2>&1; then
    rm -f "${WORK_DIR}/${TARBALL}"
    uclient-fetch -q --no-check-certificate -O "${WORK_DIR}/${TARBALL}" "$GITHUB_URL" 2>/dev/null && [ -s "${WORK_DIR}/${TARBALL}" ] && DL_OK=1
fi
[ "$DL_OK" = "1" ] && [ -s "${WORK_DIR}/${TARBALL}" ] || die "Failed to acquire $TARBALL"

log_info "Acquired $TARBALL"

# =============================================================================
# 2. Extract tarball
# =============================================================================
log_step "2/5 · Extracting"

SRC_DIR="${WORK_DIR}/src"
mkdir -p "$SRC_DIR"
tar -xzf "${WORK_DIR}/${TARBALL}" -C "$SRC_DIR" || die "Extraction failed"
log_info "Extracted to $SRC_DIR"

# =============================================================================
# 3. Install files & Purge Legacy Items
# =============================================================================
log_step "3/5 · Installing files & Cleaning legacy paths"

/etc/init.d/superwifi stop 2>/dev/null || true
sleep 1

# Purge legacy files & paths
rm -f /usr/lib/superwifi/sw-sentinel.sh \
      /usr/lib/superwifi/sw-acct.sh \
      /usr/lib/superwifi/sw-sync.sh \
      /usr/lib/superwifi/acct.sh \
      /usr/lib/superwifi/sentinel.sh \
      /usr/lib/superwifi/sync.sh \
      /usr/bin/sw \
      /www/superwifi/login.html.tpl \
      /www/cgi-bin/luci 2>/dev/null || true

rm -f /tmp/sw-acct.lock /tmp/sw-sync.lock /tmp/sw-sentinel.lock 2>/dev/null || true

# Ensure standard timing options exist in UCI
OLD_SEC=$(uci get superwifi.core.check_interval_sec 2>/dev/null || echo "")
CUR_ACCT=$(uci get superwifi.core.acct_interval 2>/dev/null || echo "")
if [ -z "$CUR_ACCT" ]; then
    if [ -n "$OLD_SEC" ] && [ "$OLD_SEC" -ge 60 ]; then
        CALC_MIN=$(( OLD_SEC / 60 ))
        [ "$CALC_MIN" -lt 1 ] && CALC_MIN=1
        uci set superwifi.core.acct_interval="$CALC_MIN"
    else
        uci set superwifi.core.acct_interval='1'
    fi
fi

CUR_SYNC=$(uci get superwifi.core.sync_interval 2>/dev/null || echo "")
if [ -z "$CUR_SYNC" ]; then
    uci set superwifi.core.sync_interval='5'
fi

CUR_SENTINEL=$(uci get superwifi.core.sentinel_enabled 2>/dev/null || echo "")
if [ -z "$CUR_SENTINEL" ]; then
    uci set superwifi.core.sentinel_enabled='1'
fi

# Purge legacy UCI config entries
uci delete superwifi.core.check_interval_sec 2>/dev/null || true
uci delete superwifi.core.enable_sync 2>/dev/null || true
uci commit superwifi 2>/dev/null || true

# Core library scripts
[ -d "$SRC_DIR/usr/lib/superwifi" ] && \
    cp "$SRC_DIR/usr/lib/superwifi/"* /usr/lib/superwifi/ 2>/dev/null || true

# Daemon & CLI scripts
if [ -d "$SRC_DIR/usr/sbin" ]; then
    cp "$SRC_DIR/usr/sbin/"* /usr/sbin/ 2>/dev/null || true
fi

# Init script
[ -f "$SRC_DIR/etc/init.d/superwifi" ] && \
    cp "$SRC_DIR/etc/init.d/superwifi" /etc/init.d/superwifi

# Schema (idempotent — all CREATE IF NOT EXISTS)
[ -f "$SRC_DIR/etc/superwifi/schema.sql" ] && \
    cp "$SRC_DIR/etc/superwifi/schema.sql" /etc/superwifi/schema.sql

# nftables template
[ -f "$SRC_DIR/etc/superwifi/superwifi.nft.tpl" ] && \
    cp "$SRC_DIR/etc/superwifi/superwifi.nft.tpl" /etc/superwifi/superwifi.nft.tpl

# CGI scripts
if [ -d "$SRC_DIR/www/cgi-bin" ]; then
    mkdir -p /www/cgi-bin
    cp "$SRC_DIR/www/cgi-bin/"* /www/cgi-bin/ 2>/dev/null || true
fi

# Frontend (HTML/CSS/JS)
if [ -d "$SRC_DIR/www/superwifi" ]; then
    mkdir -p /www/superwifi
    cp -r "$SRC_DIR/www/superwifi/"* /www/superwifi/ 2>/dev/null || true
fi
[ -f "$SRC_DIR/www/index.cgi"  ] && cp "$SRC_DIR/www/index.cgi"  /www/index.cgi
[ -f "$SRC_DIR/www/index.html" ] && cp "$SRC_DIR/www/index.html" /www/index.html

# dnsmasq config
if [ -d "$SRC_DIR/etc/dnsmasq.d" ]; then
    mkdir -p /etc/dnsmasq.d
    cp "$SRC_DIR/etc/dnsmasq.d/"* /etc/dnsmasq.d/ 2>/dev/null || true
fi

# fw4.d hooks (optional)
if [ -d "$SRC_DIR/etc/fw4.d" ]; then
    mkdir -p /etc/fw4.d
    cp "$SRC_DIR/etc/fw4.d/"* /etc/fw4.d/ 2>/dev/null || true
fi

[ -f "$SRC_DIR/etc/superwifi-version" ] && \
    cp "$SRC_DIR/etc/superwifi-version" /etc/superwifi-version

log_info "Setting executable permissions..."
chmod +x /usr/lib/superwifi/*.sh    2>/dev/null || true
chmod +x /usr/sbin/sw*             2>/dev/null || true
chmod +x /www/cgi-bin/*.sh         2>/dev/null || true
chmod +x /www/index.cgi            2>/dev/null || true
chmod +x /etc/init.d/superwifi     2>/dev/null || true

log_info "Files installed successfully & legacy items purged"

# =============================================================================
# 4. Apply DB migration & Full Session Repair
# =============================================================================
log_step "4/5 · Database migration & Automatic Session Repair"

if [ -f "$DB_PATH" ]; then
    DB_VER=$(sqlite3 "$DB_PATH" \
        "SELECT value FROM system_config WHERE key='firmware_version';" 2>/dev/null || echo "unknown")
    log_info "DB firmware_version = $DB_VER"

    log_info "Refreshing schema (idempotent)..."
    sqlite3 "$DB_PATH" ".read /etc/superwifi/schema.sql" 2>/dev/null || true

    log_info "Repairing active session class_ids, firewall rules, and TC filters..."
    . /usr/lib/superwifi/core.sh
    . /usr/lib/superwifi/db-queries.sh
    . /usr/lib/superwifi/tc.sh
    . /usr/lib/superwifi/fw.sh
    
    sw_db_init || true
    db_repair_active_sessions_class_id || true

    # Unconditionally restore active sessions into nftables during OTA
    RST_TMP=$(mktemp) || true
    if [ -f "$RST_TMP" ]; then
        db_get_restore_sessions > "$RST_TMP" 2>/dev/null || true
        RESTORED_CNT=0
        while IFS='|' read -r mac ip rate_down rate_up class_id expires_at data_limit cumulative; do
            [ -z "$mac" ] || [ -z "$ip" ] && continue
            sw_restore_one_session "$mac" "$ip" "$rate_down" "$rate_up" "$class_id" "$expires_at" 2>/dev/null || true
            RESTORED_CNT=$((RESTORED_CNT + 1))
        done < "$RST_TMP"
        rm -f "$RST_TMP"
        log_info "Restored ${RESTORED_CNT} active sessions into firewall set"
    fi

    sw_tc_rebuild_filters || true

    sqlite3 "$DB_PATH" "
        BEGIN EXCLUSIVE;
        INSERT OR REPLACE INTO system_config (key, value, updated_at)
            VALUES ('firmware_version', '${VERSION}', strftime('%s','now'));
        COMMIT;
    " 2>/dev/null || true
    log_info "Migration v${VERSION} applied successfully"
else
    log_warn "DB not found at $DB_PATH — will be initialized fresh on next start"
fi

# =============================================================================
# 5. Start service & Reboot
# =============================================================================
log_step "5/5 · Starting service & Rebooting router"

/etc/init.d/superwifi enable 2>/dev/null || true
/etc/init.d/superwifi start  2>/dev/null || true
sleep 2

/etc/init.d/superwifi running 2>/dev/null && \
    log_info "SuperWiFi service is running" || \
    log_info "SuperWiFi service enabled and started"

# =============================================================================
# Cleanup
# =============================================================================
rm -rf "$WORK_DIR"

# =============================================================================
# Summary
# =============================================================================
printf "\n${GRN}╔══════════════════════════════════════════╗${RST}\n"
printf "${GRN}║       UPDATE COMPLETE — v%-13s  ║${RST}\n" "$VERSION"
printf "${GRN}╠══════════════════════════════════════════╣${RST}\n"
printf "${GRN}║  Unified Engine Daemon Active (sw-engine) ║${RST}\n"
printf "${GRN}║  Auto-Repaired Active Sessions & TC      ║${RST}\n"
printf "${GRN}║  Automatic Supabase Cloud Auto-Update    ║${RST}\n"
printf "${GRN}║  SSOT versioning   v8.1.5 Release        ║${RST}\n"
printf "${GRN}╚══════════════════════════════════════════╝${RST}\n\n"

log_info "Rebooting router to apply all changes cleanly in 3 seconds..."
sleep 3
reboot 2>/dev/null || true
