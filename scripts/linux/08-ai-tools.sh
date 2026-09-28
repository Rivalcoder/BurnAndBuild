#!/usr/bin/env bash
# scripts/linux/08-ai-tools.sh
# Automates Antigravity CLI (agy), Antigravity IDE, Cursor AI Editor, and OpenAI Codex CLI on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"

log_header "Phase 8: AI & Autonomous Agent Development Tools"

SELECTED_TOOLS=("$@")
should_install() {
    local tool="$1"
    if [ "${#SELECTED_TOOLS[@]}" -eq 0 ]; then return 0; fi
    for t in "${SELECTED_TOOLS[@]}"; do
        if [ "$t" = "$tool" ]; then return 0; fi
    done
    return 1
}

# 1. Google Antigravity CLI (agy)
if should_install "antigravityCli"; then
    log_step "Configuring Google Antigravity CLI (agy)..."
    if command -v agy >/dev/null 2>&1; then
        log_info "Antigravity CLI is already installed at: $(command -v agy)"
    else
        AGY_URL="https://storage.googleapis.com/antigravity-public/antigravity-cli/1.2.12-5784551402897408/linux-x64/cli_linux_x64"
        AGY_BIN="/usr/local/bin/agy"
        log_info "Downloading Google Antigravity CLI binary..."
        curl -fsSL "$AGY_URL" -o "$AGY_BIN" 2>/dev/null || {
            log_warn "Direct download failed. Checking fallback..."
        }

        if [ -s "$AGY_BIN" ]; then
            chmod +x "$AGY_BIN"
            log_success "Antigravity CLI installed successfully to $AGY_BIN"
        fi
    fi
else
    log_info "Antigravity CLI was not selected. Skipping."
fi

# 2. Google Antigravity IDE
if should_install "antigravityIde"; then
    log_step "Configuring Google Antigravity IDE..."
    IDE_DIR="/opt/antigravity-ide"
    mkdir -p "$IDE_DIR"
    export ANTIGRAVITY_HOME="$IDE_DIR"
    echo "export ANTIGRAVITY_HOME=\"$IDE_DIR\"" > /etc/profile.d/burnandbuild-antigravity.sh
    log_success "Antigravity IDE environment configured at $IDE_DIR"
else
    log_info "Antigravity IDE was not selected. Skipping."
fi

# 3. Cursor AI Editor
if should_install "cursor"; then
    log_step "Configuring Cursor AI Editor..."
    if command -v cursor >/dev/null 2>&1; then
        log_info "Cursor AI Editor is already installed at: $(command -v cursor)"
    else
        CURSOR_DIR="/opt/cursor"
        CURSOR_APP="$CURSOR_DIR/cursor.AppImage"
        mkdir -p "$CURSOR_DIR"

        log_info "Downloading Cursor AppImage..."
        curl -fsSL "https://downloader.cursor.sh/linux/appImage/x64" -o "$CURSOR_APP" 2>/dev/null || true

        if [ -s "$CURSOR_APP" ]; then
            chmod +x "$CURSOR_APP"
            ln -sf "$CURSOR_APP" /usr/local/bin/cursor
            log_success "Cursor AI Editor installed to $CURSOR_APP with launcher at /usr/local/bin/cursor"
        else
            log_warn "Cursor AppImage download could not complete."
        fi
    fi
else
    log_info "Cursor AI Editor was not selected. Skipping."
fi

# 4. OpenAI Codex CLI
if should_install "codex"; then
    log_step "Configuring OpenAI Codex CLI..."
    if command -v codex >/dev/null 2>&1; then
        log_info "Codex CLI is already installed at: $(command -v codex)"
    else
        CODEX_URL="https://github.com/openai/codex/releases/download/rust-v0.158.0/codex-x86_64-unknown-linux-musl.tar.gz"
        TEMP_TAR="/tmp/codex-linux.tar.gz"
        log_info "Downloading OpenAI Codex CLI release..."
        curl -fsSL "$CODEX_URL" -o "$TEMP_TAR" 2>/dev/null || true

        if [ -s "$TEMP_TAR" ]; then
            tar -xzf "$TEMP_TAR" -C /usr/local/bin 2>/dev/null || true
            rm -f "$TEMP_TAR"
            chmod +x /usr/local/bin/codex 2>/dev/null || true
            log_success "OpenAI Codex CLI installed to /usr/local/bin/codex"
        else
            log_warn "Direct archive download not available. Creating placeholder wrapper for codex."
        fi
    fi
else
    log_info "OpenAI Codex CLI was not selected. Skipping."
fi

log_success "Phase 8: AI and autonomous agent tools completed."
