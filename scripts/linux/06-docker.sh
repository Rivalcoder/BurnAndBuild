#!/usr/bin/env bash
# scripts/linux/06-docker.sh
# Automates Docker Engine, Docker Compose, service activation, and rootless group on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/package-manager.sh"

log_header "Phase 6: Docker Engine & Container Runtime Automation"

if command -v docker >/dev/null 2>&1; then
    log_info "Docker is already installed: $(docker --version)"
else
    log_step "Installing Docker Engine via official Docker installation script..."
    curl -fsSL https://get.docker.com | sh || {
        log_warn "Official script failed. Trying package manager installation..."
        case "$PKG_MANAGER" in
            apt)
                pm_install docker.io docker-compose-plugin
                ;;
            dnf|yum)
                pm_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
                ;;
            pacman)
                pm_install docker docker-compose
                ;;
        esac
    }
fi

# Enable and Start Docker Service (if systemd is active)
if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    log_step "Enabling and starting Docker systemd service..."
    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true
fi

# Add target user to docker group
TARGET_USER="${SUDO_USER:-$USER}"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
    log_step "Adding user '$TARGET_USER' to docker group for non-root usage..."
    groupadd -f docker 2>/dev/null || true
    usermod -aG docker "$TARGET_USER" 2>/dev/null || true
    log_success "User '$TARGET_USER' added to docker group."
fi

if command -v docker >/dev/null 2>&1; then
    log_success "Docker Engine verified: $(docker --version)"
    if docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose verified: $(docker compose version)"
    fi
fi

log_success "Phase 6: Docker setup completed."
