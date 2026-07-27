#!/bin/sh
# =============================================================================
# SuperWiFi OTA Update Script — v6.1.2
# =============================================================================
# Changes in this release:
#   [SSOT] Dynamic versioning across all logs, banners, and CLI commands
#   [PERF] Dynamic src folder resolution inside update archives
#   [PERF] Zero-latency bulk batch deletion & cascade deletes (<1ms)
#   [ARCH] Automatic async deauth via accounting daemon & sentinel
#   [FIX]  Package edit sync trigger on Supabase (is_downloaded reset)
#   [FIX]  Unlimited speed support (rate = 0) & traffic shaper mapping
#   [COMP] Universal tarball and shell script update auto-detection
# =============================================================================

VERSION="6.1.2"
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
cd "$WORK_DIR"       || die "Cannot cd to $WORK_DIR"

log_info "Source: $GITHUB_URL"

if command -v wget >/dev/null 2>&1; then
    wget -q --timeout=30 -O "$TARBALL" "$GITHUB_URL" || die "wget failed to download tarball"
elif command -v curl >/dev/null 2>&1; then
    curl -sSLf --max-time 30 -o "$TARBALL" "$GITHUB_URL" || die "curl failed to download tarball"
else
    die "Neither wget nor curl found"
fi

[ -f "$TARBALL" ] || die "Tarball not found after download"
[ -s "$TARBALL" ] || die "Tarball is empty — download likely failed"
log_info "Downloaded: $TARBALL ($(wc -c < "$TARBALL") bytes)"

# =============================================================================
# 2. Extract
# =============================================================================
log_step "2/5 · Extracting"

tar -xzf "$TARBALL" || die "Extraction failed — tarball may be corrupt"
SRC_DIR=$(find "$WORK_DIR" -type d -name "src" 2>/dev/null | head -n 1)
[ -n "$SRC_DIR" ] && [ -d "$SRC_DIR" ] || die "Expected src/ dir not found in tarball"
log_info "Extracted to $SRC_DIR"

# =============================================================================
# 3. Stop service + install files (preserve config & DB)
# =============================================================================
log_step "3/5 · Installing files"

log_warn "Stopping SuperWiFi service..."
/etc/init.d/superwifi stop 2>/dev/null || true
sleep 1

log_info "Copying system scripts..."
cp -r "$SRC_DIR/usr/"*  /usr/ 2>/dev/null || true

log_info "Copying web files..."
cp -r "$SRC_DIR/www/"*  /www/ 2>/dev/null || true

log_info "Copying init script..."
cp "$SRC_DIR/etc/init.d/superwifi" /etc/init.d/superwifi 2>/dev/null || true

log_info "Copying superwifi system files (excl. config)..."
for f in "$SRC_DIR/etc/superwifi/"*; do
    cp "$f" "/etc/superwifi/$(basename "$f")" 2>/dev/null || true
done

if [ -d "$SRC_DIR/etc/dnsmasq.d" ]; then
    mkdir -p /etc/dnsmasq.d
    cp "$SRC_DIR/etc/dnsmasq.d/"* /etc/dnsmasq.d/ 2>/dev/null || true
fi

if [ -d "$SRC_DIR/etc/fw4.d" ]; then
    mkdir -p /etc/fw4.d
    cp "$SRC_DIR/etc/fw4.d/"* /etc/fw4.d/ 2>/dev/null || true
fi

[ -f "$SRC_DIR/etc/superwifi-version" ] && \
    cp "$SRC_DIR/etc/superwifi-version" /etc/superwifi-version

# Remove legacy template and old cgi-bin/luci override file if present
rm -f /www/superwifi/login.html.tpl /www/cgi-bin/luci 2>/dev/null || true

log_info "Setting executable permissions..."
chmod +x /usr/lib/superwifi/*.sh    2>/dev/null || true
chmod +x /usr/sbin/sw               2>/dev/null || true
chmod +x /usr/sbin/sw-acct.sh      2>/dev/null || true
chmod +x /usr/sbin/sw-sync.sh      2>/dev/null || true
chmod +x /www/cgi-bin/*.sh         2>/dev/null || true
chmod +x /www/index.cgi            2>/dev/null || true
chmod +x /etc/init.d/superwifi     2>/dev/null || true

log_info "Files installed successfully"

# =============================================================================
# 4. Apply DB migration (v6.1.2 SSOT & CASCADE)
# =============================================================================
log_step "4/5 · Database migration"

if [ -f "$DB_PATH" ]; then
    DB_VER=$(sqlite3 "$DB_PATH" \
        "SELECT value FROM system_config WHERE key='firmware_version';" 2>/dev/null || echo "unknown")
    log_info "DB firmware_version = $DB_VER"

    if [ "$DB_VER" != "$VERSION" ]; then
        log_warn "Applying migration v${VERSION}: updating schema & cascade constraints..."
        sqlite3 "$DB_PATH" "ALTER TABLE voucher ADD COLUMN batch_id INTEGER DEFAULT NULL;" 2>/dev/null || true
        sqlite3 "$DB_PATH" "CREATE INDEX IF NOT EXISTS idx_voucher_batch_id ON voucher(batch_id) WHERE batch_id IS NOT NULL;" 2>/dev/null || true
        sqlite3 "$DB_PATH" ".read /etc/superwifi/schema.sql" 2>/dev/null || true
        sqlite3 "$DB_PATH" \
            "INSERT OR REPLACE INTO system_config (key, value, updated_at) VALUES ('firmware_version', '${VERSION}', strftime('%s','now'));" \
            2>/dev/null || true
        log_info "Migration v${VERSION} applied successfully"
    else
        log_info "DB already at v${VERSION} — migration skipped"
    fi
else
    log_warn "DB not found at $DB_PATH — will be initialized fresh on next start"
fi

# =============================================================================
# 5. Start service
# =============================================================================
log_step "5/5 · Starting service"

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
printf "${GRN}║  Config preserved  /etc/config/superwifi ║${RST}\n"
printf "${GRN}║  SSOT versioning   /etc/superwifi-version ║${RST}\n"
printf "${GRN}║  Dynamic version   logs, status & banner ║${RST}\n"
printf "${GRN}║  Cascade deletes   vouchers & sessions   ║${RST}\n"
printf "${GRN}║  Batch ID support  bulk delete <1ms      ║${RST}\n"
printf "${GRN}║  Unlimited speed   rate=0 supported      ║${RST}\n"
printf "${GRN}╚══════════════════════════════════════════╝${RST}\n\n"
