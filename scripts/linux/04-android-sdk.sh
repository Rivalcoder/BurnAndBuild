#!/usr/bin/env bash
# scripts/linux/04-android-sdk.sh
# Automates Android Command-Line Tools, Platform-Tools (adb), Build-Tools, and Licenses on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"

log_header "Phase 4: Android & Mobile SDK Automation"

ANDROID_HOME="/opt/android-sdk"
CMDLINE_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
CMDLINE_LATEST_DIR="$ANDROID_HOME/cmdline-tools/latest"
SDKMANAGER="$CMDLINE_LATEST_DIR/bin/sdkmanager"

# 1. Check JAVA_HOME
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    for cand in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/temurin-17-*; do
        if [ -d "$cand" ]; then
            export JAVA_HOME="$cand"
            break
        fi
    done
fi

if [ -n "$JAVA_HOME" ]; then
    log_info "Using JAVA_HOME: $JAVA_HOME"
else
    log_warn "JAVA_HOME is not set. Android SDK tools require Java 17."
fi

# 2. Download and Setup Command-Line Tools
if [ ! -f "$SDKMANAGER" ]; then
    log_step "Downloading Android command-line tools for Linux..."
    mkdir -p "$ANDROID_HOME"
    TEMP_ZIP="/tmp/android-cmdline-tools.zip"
    TEMP_EXTRACT="/tmp/android-cmdline-extract"

    curl -fsSL "$CMDLINE_ZIP_URL" -o "$TEMP_ZIP"
    rm -rf "$TEMP_EXTRACT"
    mkdir -p "$TEMP_EXTRACT"
    unzip -qo "$TEMP_ZIP" -d "$TEMP_EXTRACT"

    mkdir -p "$CMDLINE_LATEST_DIR"
    cp -r "$TEMP_EXTRACT/cmdline-tools/"* "$CMDLINE_LATEST_DIR/"
    rm -rf "$TEMP_EXTRACT" "$TEMP_ZIP"
    chmod +x "$CMDLINE_LATEST_DIR/bin/"* 2>/dev/null || true
    log_success "Android cmdline-tools extracted to $CMDLINE_LATEST_DIR"
fi

# 3. Accept Licenses and Install Core Components
if [ -x "$SDKMANAGER" ]; then
    log_step "Accepting Android SDK licenses and installing platform-tools..."
    export ANDROID_HOME
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$CMDLINE_LATEST_DIR/bin:$ANDROID_HOME/platform-tools:$PATH"

    # Accept all licenses unattended
    yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true

    log_info "Installing platform-tools, build-tools 34.0.0, platforms android-34..."
    yes | "$SDKMANAGER" "platform-tools" "build-tools;34.0.0" "platforms;android-34" >/dev/null 2>&1 || true

    # Link adb and sdkmanager to /usr/local/bin
    if [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
        ln -sf "$ANDROID_HOME/platform-tools/adb" /usr/local/bin/adb
        log_success "Android platform-tools (adb) verified: $(adb --version | head -n 1)"
    fi
    ln -sf "$SDKMANAGER" /usr/local/bin/sdkmanager
fi

# 4. Export Global Environment Variables
cat << EOF > /etc/profile.d/burnandbuild-android.sh
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/build-tools/34.0.0:\$PATH"
EOF

# Grant access to target user
TARGET_USER="${SUDO_USER:-$USER}"
chown -R "$TARGET_USER:$TARGET_USER" "$ANDROID_HOME" 2>/dev/null || true

log_success "Phase 4: Android SDK installation completed."
