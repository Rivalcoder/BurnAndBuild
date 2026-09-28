#!/usr/bin/env bash
# scripts/linux/07-ides-editors.sh
# Installs VS Code (+ dynamic extensions), Chrome/Brave, Postman, DBeaver on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/package-manager.sh"

log_header "Phase 7: IDEs, Code Editors, Browsers & API Tools"

SELECTED_TOOLS=("$@")
should_install() {
    local tool="$1"
    if [ "${#SELECTED_TOOLS[@]}" -eq 0 ]; then return 0; fi
    for t in "${SELECTED_TOOLS[@]}"; do
        if [ "$t" = "$tool" ]; then return 0; fi
    done
    return 1
}

# 1. Visual Studio Code
if should_install "vscode"; then
    log_step "Configuring Visual Studio Code..."
    if ! command -v code >/dev/null 2>&1; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            log_info "Adding Microsoft Visual Studio Code repository..."
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/packages.microsoft.gpg 2>/dev/null || true
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
            apt-get update -y >/dev/null 2>&1 || true
            pm_install code
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
            cat << 'EOF' > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            dnf check-update -y || true
            dnf install code -y || true
        elif [ "$PKG_MANAGER" = "pacman" ]; then
            pacman -S --noconfirm code || true
        fi
    fi

    if command -v code >/dev/null 2>&1; then
        log_success "Visual Studio Code verified: $(code --version | head -n 1)"

        # Install tailored extensions for selected tools as the target user
        TARGET_USER="${SUDO_USER:-$USER}"
        EXTENSIONS=(
            "eamodio.gitlens"
            "EditorConfig.EditorConfig"
            "tamasfe.even-better-toml"
            "redhat.vscode-yaml"
        )

        if should_install "flutter"; then
            EXTENSIONS+=("Dart-Code.flutter" "Dart-Code.dart-code")
        fi
        if should_install "python"; then
            EXTENSIONS+=("ms-python.python" "ms-python.vscode-pylance")
        fi
        if should_install "node"; then
            EXTENSIONS+=("dbaeumer.vscode-eslint" "esbenp.prettier-vscode")
        fi
        if should_install "docker"; then
            EXTENSIONS+=("ms-azuretools.vscode-docker")
        fi
        if should_install "java"; then
            EXTENSIONS+=("vscjava.vscode-java-pack")
        fi
        if should_install "jira"; then
            EXTENSIONS+=("Atlassian.atlascode")
        fi

        log_step "Installing ${#EXTENSIONS[@]} tailored VS Code extension(s)..."
        for ext in "${EXTENSIONS[@]}"; do
            su - "$TARGET_USER" -c "code --install-extension $ext --force" >/dev/null 2>&1 || true
        done
        log_success "VS Code extensions installed."
    fi
else
    log_info "VS Code was not selected. Skipping."
fi

# 2. Fast Text Editor (Micro/Nano)
if should_install "notepadpp"; then
    log_step "Configuring lightweight text editor (Micro/Nano)..."
    pm_install nano 2>/dev/null || true
    if ! command -v micro >/dev/null 2>&1; then
        curl -fsSL https://getmic.ro | bash 2>/dev/null || true
        if [ -f "micro" ]; then
            mv micro /usr/local/bin/micro
            log_success "Micro modern terminal editor installed to /usr/local/bin/micro"
        fi
    fi
fi

# 3. Google Chrome Browser
if should_install "chrome"; then
    log_step "Configuring Google Chrome..."
    if ! command -v google-chrome >/dev/null 2>&1 && ! command -v google-chrome-stable >/dev/null 2>&1; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            CHROME_DEB="/tmp/google-chrome-stable_current_amd64.deb"
            curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$CHROME_DEB"
            dpkg -i "$CHROME_DEB" >/dev/null 2>&1 || apt-get -f install -y >/dev/null 2>&1 || true
            rm -f "$CHROME_DEB"
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm >/dev/null 2>&1 || true
        fi
    fi

    if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
        log_success "Google Chrome installed successfully."
    fi
fi

# 4. Brave Browser
if should_install "brave"; then
    log_step "Configuring Brave Browser..."
    if ! command -v brave-browser >/dev/null 2>&1; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 2>/dev/null || true
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
            apt-get update -y >/dev/null 2>&1 || true
            pm_install brave-browser
        fi
    fi
fi

# 5. Postman API Client
if should_install "postman"; then
    log_step "Configuring Postman API Client..."
    POSTMAN_DIR="/opt/postman"
    if [ ! -d "$POSTMAN_DIR" ]; then
        TEMP_TAR="/tmp/postman-linux-x64.tar.gz"
        curl -fsSL "https://dl.pstmn.io/download/latest/linux_64" -o "$TEMP_TAR" 2>/dev/null || true
        if [ -s "$TEMP_TAR" ]; then
            tar -xzf "$TEMP_TAR" -C /opt
            rm -f "$TEMP_TAR"
            ln -sf /opt/Postman/Postman /usr/local/bin/postman 2>/dev/null || true
            log_success "Postman installed to /opt/Postman"
        fi
    fi
fi

# 6. DBeaver Community Edition
if should_install "dbeaver"; then
    log_step "Configuring DBeaver Community Edition..."
    if ! command -v dbeaver >/dev/null 2>&1; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            DBEAVER_DEB="/tmp/dbeaver-ce_latest_amd64.deb"
            curl -fsSL "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" -o "$DBEAVER_DEB" 2>/dev/null || true
            if [ -s "$DBEAVER_DEB" ]; then
                dpkg -i "$DBEAVER_DEB" >/dev/null 2>&1 || apt-get -f install -y >/dev/null 2>&1 || true
                rm -f "$DBEAVER_DEB"
                log_success "DBeaver Community installed."
            fi
        fi
    fi
fi

log_success "Phase 7: IDEs, editors, and tools phase completed."
