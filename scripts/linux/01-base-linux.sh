#!/usr/bin/env bash
# scripts/linux/01-base-linux.sh
# Linux System Optimizations & Dev Essentials for BurnAndBuild

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/package-manager.sh"

log_header "Phase 1: Linux System Optimizations & Dev Essentials"

# 1. Update Package Index
pm_update

# 2. Install Essential Build & Network Utilities
case "$PKG_MANAGER" in
    apt)
        pm_install build-essential curl wget gnupg ca-certificates \
                   software-properties-common apt-transport-https \
                   unzip tar gzip xz-utils lsb-release
        ;;
    dnf|yum)
        pm_install @development-tools curl wget gnupg2 ca-certificates \
                   unzip tar gzip xz
        ;;
    pacman)
        pm_install base-devel curl wget gnupg ca-certificates unzip tar gzip xz
        ;;
    *)
        log_warn "Unknown package manager. Attempting minimal tool installation."
        ;;
esac

# 3. Apply Inotify File Watcher Limits (Crucial for IDEs, Flutter, Webpack/Vite)
log_step "Configuring file watcher limits (inotify)..."
SYSCTL_FILE="/etc/sysctl.d/99-burnandbuild.conf"
cat << 'EOF' > "$SYSCTL_FILE"
# Configured by BurnAndBuild Automation
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
fs.file-max = 2097152
EOF

sysctl -p "$SYSCTL_FILE" >/dev/null 2>&1 || true
log_success "Inotify limits configured: max_user_watches = 524288"

# 4. Create Standard Persistent Workspace Directory
TARGET_USER="${SUDO_USER:-$USER}"
WORKSPACE_DIR="/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
    log_step "Creating workspace directory at $WORKSPACE_DIR..."
    mkdir -p "$WORKSPACE_DIR"
    chown -R "$TARGET_USER:$TARGET_USER" "$WORKSPACE_DIR" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR"
fi
log_success "Workspace directory ready at $WORKSPACE_DIR"

log_success "Phase 1: Linux base system configuration completed."
