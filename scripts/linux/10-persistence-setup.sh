#!/usr/bin/env bash
# scripts/linux/10-persistence-setup.sh
# Sets up workspace persistence, SSH keypair, Git identity, and cache directories on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"

log_header "Phase 10: Persistence Setup, Git Identity & SSH Keys"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~$TARGET_USER")
GIT_NAME="${1:-}"
GIT_EMAIL="${2:-}"

# 1. Ensure /workspace is owned by target user
mkdir -p /workspace
chown -R "$TARGET_USER:$TARGET_USER" /workspace 2>/dev/null || true
log_success "Workspace directory verified at /workspace"

# 2. Configure Git Identity
if [ -n "$GIT_NAME" ]; then
    log_step "Setting global Git user name: $GIT_NAME"
    su - "$TARGET_USER" -c "git config --global user.name '$GIT_NAME'" 2>/dev/null || true
fi

if [ -n "$GIT_EMAIL" ]; then
    log_step "Setting global Git user email: $GIT_EMAIL"
    su - "$TARGET_USER" -c "git config --global user.email '$GIT_EMAIL'" 2>/dev/null || true
fi

# 3. SSH Keypair Generation (ED25519)
SSH_DIR="$TARGET_HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
    log_step "Generating ED25519 SSH keypair for $TARGET_USER..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    KEY_COMMENT="${GIT_EMAIL:-dev@burnandbuild-vm}"
    ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$SSH_KEY" -N "" >/dev/null 2>&1 || true

    chown -R "$TARGET_USER:$TARGET_USER" "$SSH_DIR" 2>/dev/null || true
    chmod 600 "$SSH_KEY" 2>/dev/null || true
    chmod 644 "$SSH_KEY.pub" 2>/dev/null || true

    log_success "SSH key generated at: $SSH_KEY"
    if [ -f "$SSH_KEY.pub" ]; then
        log_info "Public SSH Key:"
        cat "$SSH_KEY.pub"
    fi
else
    log_info "Existing SSH key found at: $SSH_KEY"
fi

# 4. Prepare Cache Directories
for cdir in "$TARGET_HOME/.cache" "$TARGET_HOME/.gradle" "$TARGET_HOME/.npm" "$TARGET_HOME/.pub-cache"; do
    mkdir -p "$cdir"
    chown -R "$TARGET_USER:$TARGET_USER" "$cdir" 2>/dev/null || true
done

log_success "Phase 10: Persistence, SSH, and cache setup completed."
