#!/usr/bin/env bash
# scripts/linux/05-flutter-sdk.sh
# Automates Google Flutter SDK installation, PATH configuration, and doctor on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"

log_header "Phase 5: Google Flutter SDK Automation"

FLUTTER_DIR="/opt/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"

if [ -x "$FLUTTER_BIN" ]; then
    log_info "Flutter SDK is already present at: $FLUTTER_DIR"
else
    log_step "Installing Google Flutter SDK (stable channel)..."
    mkdir -p /opt
    if command -v git >/dev/null 2>&1; then
        log_info "Cloning Flutter stable repository into $FLUTTER_DIR..."
        git clone -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR" --depth 1
    else
        log_warn "Git not available. Downloading Flutter Linux release archive..."
        TEMP_TAR="/tmp/flutter_linux.tar.xz"
        curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz" -o "$TEMP_TAR"
        tar -xf "$TEMP_TAR" -C /opt
        rm -f "$TEMP_TAR"
    fi
fi

# Set permissions
TARGET_USER="${SUDO_USER:-$USER}"
chown -R "$TARGET_USER:$TARGET_USER" "$FLUTTER_DIR" 2>/dev/null || true

# Symlink binaries
ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter
ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart

# Export environment variables
cat << 'EOF' > /etc/profile.d/burnandbuild-flutter.sh
export FLUTTER_HOME="/opt/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
EOF

# Pre-cache and configure
export PATH="$FLUTTER_DIR/bin:$PATH"
log_step "Configuring Flutter..."
su - "$TARGET_USER" -c "flutter config --no-analytics" 2>/dev/null || flutter config --no-analytics 2>/dev/null || true

if [ -d "/opt/android-sdk" ]; then
    log_info "Linking Android SDK to Flutter..."
    su - "$TARGET_USER" -c "flutter config --android-sdk /opt/android-sdk" 2>/dev/null || flutter config --android-sdk /opt/android-sdk 2>/dev/null || true
fi

log_step "Running flutter doctor..."
su - "$TARGET_USER" -c "flutter doctor" 2>/dev/null || flutter doctor 2>/dev/null || true

log_success "Phase 5: Flutter SDK setup completed."
