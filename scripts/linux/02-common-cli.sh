#!/usr/bin/env bash
# scripts/linux/02-common-cli.sh
# Installs Core CLI Tools: Git, GitHub CLI, jq, ripgrep, fzf, 7-zip, tmux, zsh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/package-manager.sh"

log_header "Phase 2: Core CLI Suite & Shell Tools"

# 1. Install standard CLI packages from system repos
case "$PKG_MANAGER" in
    apt)
        pm_install git jq ripgrep fzf p7zip-full tmux zsh
        ;;
    dnf|yum)
        pm_install git jq ripgrep fzf p7zip tmux zsh
        ;;
    pacman)
        pm_install git jq ripgrep fzf p7zip tmux zsh
        ;;
    *)
        ensure_command git
        ensure_command jq
        ;;
esac

# 2. Install GitHub CLI (gh) via official repo if missing
if ! command -v gh >/dev/null 2>&1; then
    log_step "Installing official GitHub CLI (gh)..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        mkdir -p -m 755 /etc/apt/keyrings
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update -y >/dev/null 2>&1 || true
        pm_install gh
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        dnf install 'dnf-command(config-manager)' -y >/dev/null 2>&1 || true
        dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null 2>&1 || true
        dnf install gh -y >/dev/null 2>&1 || true
    fi
fi

if command -v gh >/dev/null 2>&1; then
    log_success "GitHub CLI verified: $(gh --version | head -n 1)"
fi

# 3. Configure Git System Defaults
git config --system init.defaultBranch main 2>/dev/null || true
git config --system core.autocrlf input 2>/dev/null || true

log_success "Phase 2: Core CLI suite installed successfully."
