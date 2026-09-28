#!/usr/bin/env bash
# scripts/linux/03-runtimes.sh
# Installs Java JDK 17, Node.js LTS (fnm), Python 3 & uv, and Gradle on Linux

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source modules
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/package-manager.sh"

log_header "Phase 3: Development Runtimes (Java, Node.js, Python, Gradle)"

SELECTED_TOOLS=("$@")
should_install() {
    local tool="$1"
    if [ "${#SELECTED_TOOLS[@]}" -eq 0 ]; then return 0; fi
    for t in "${SELECTED_TOOLS[@]}"; do
        if [ "$t" = "$tool" ]; then return 0; fi
    done
    return 1
}

# 1. Java JDK 17
if should_install "java"; then
    log_step "Configuring Java Development Kit (JDK 17 LTS)..."
    if command -v javac >/dev/null 2>&1 && java -version 2>&1 | grep -q "17"; then
        log_info "Java JDK 17 is already installed: $(java -version 2>&1 | head -n 1)"
    else
        case "$PKG_MANAGER" in
            apt)
                pm_install openjdk-17-jdk openjdk-17-jre-headless
                ;;
            dnf|yum)
                pm_install java-17-openjdk-devel
                ;;
            pacman)
                pm_install jdk17-openjdk
                ;;
        esac
    fi

    # Locate and set JAVA_HOME
    JAVA_HOME_PATH=""
    for cand in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/temurin-17-* /usr/lib/jvm/default-java; do
        if [ -d "$cand" ] && [ -f "$cand/bin/javac" ]; then
            JAVA_HOME_PATH="$cand"
            break
        fi
    done

    if [ -n "$JAVA_HOME_PATH" ]; then
        log_success "Discovered Java 17 home at: $JAVA_HOME_PATH"
        export JAVA_HOME="$JAVA_HOME_PATH"
        echo "export JAVA_HOME=\"$JAVA_HOME_PATH\"" > /etc/profile.d/burnandbuild-java.sh
        echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> /etc/profile.d/burnandbuild-java.sh
    fi
else
    log_info "Java was not selected. Skipping."
fi

# 2. Node.js LTS (via Fast Node Manager fnm or NodeSource)
if should_install "node"; then
    log_step "Configuring Node.js LTS..."
    if command -v node >/dev/null 2>&1; then
        log_info "Node.js is already installed: $(node --version)"
    else
        log_info "Installing Fast Node Manager (fnm)..."
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell || true

        if command -v fnm >/dev/null 2>&1; then
            log_info "Installing Node.js LTS via fnm..."
            export FNM_DIR="/opt/fnm"
            mkdir -p "$FNM_DIR"
            fnm install --lts
            fnm default lts-latest
            # Link current node and npm to /usr/local/bin for global accessibility
            NODE_PATH=$(fnm current 2>/dev/null || true)
            if [ -n "$NODE_PATH" ]; then
                fnm exec -- node -v || true
            fi
        fi

        # Fallback to NodeSource repository if needed
        if ! command -v node >/dev/null 2>&1; then
            log_info "Installing Node.js LTS via NodeSource..."
            if [ "$PKG_MANAGER" = "apt" ]; then
                curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
                pm_install nodejs
            elif [ "$PKG_MANAGER" = "dnf" ]; then
                curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
                pm_install nodejs
            fi
        fi
    fi

    if command -v node >/dev/null 2>&1; then
        log_success "Node.js verified: $(node --version), npm: $(npm --version 2>/dev/null || echo 'installed')"
    fi
else
    log_info "Node.js was not selected. Skipping."
fi

# 3. Python 3 & uv (Astral Ultra-fast Python package manager)
if should_install "python"; then
    log_step "Configuring Python 3 and uv package manager..."
    case "$PKG_MANAGER" in
        apt)
            pm_install python3 python3-pip python3-venv python3-dev
            ;;
        dnf|yum)
            pm_install python3 python3-pip python3-devel
            ;;
        pacman)
            pm_install python python-pip
            ;;
    esac

    # Install uv globally
    if ! command -v uv >/dev/null 2>&1; then
        log_info "Installing Astral uv (ultra-fast package manager)..."
        curl -LsSf https://astral.sh/uv/install.sh | env CARGO_DIST_FORCE_INSTALL_DIR=/usr/local/bin sh || true
    fi

    if command -v uv >/dev/null 2>&1; then
        log_success "Astral uv installed: $(uv --version)"
    fi
    if command -v python3 >/dev/null 2>&1; then
        log_success "Python verified: $(python3 --version)"
    fi
else
    log_info "Python was not selected. Skipping."
fi

# 4. Gradle Build Automation Tool
if should_install "gradle"; then
    log_step "Configuring Gradle Build Tool..."
    if command -v gradle >/dev/null 2>&1; then
        log_info "Gradle is already installed: $(gradle --version | head -n 3 | tr '\n' ' ')"
    else
        GRADLE_VER="8.7"
        GRADLE_ZIP="/tmp/gradle-${GRADLE_VER}-bin.zip"
        GRADLE_INSTALL_DIR="/opt/gradle"
        mkdir -p "$GRADLE_INSTALL_DIR"

        log_info "Downloading Gradle $GRADLE_VER..."
        curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip" -o "$GRADLE_ZIP"
        unzip -qo "$GRADLE_ZIP" -d "$GRADLE_INSTALL_DIR"
        rm -f "$GRADLE_ZIP"

        ln -sf "$GRADLE_INSTALL_DIR/gradle-${GRADLE_VER}/bin/gradle" /usr/local/bin/gradle
        log_success "Gradle installed to $GRADLE_INSTALL_DIR/gradle-${GRADLE_VER}"
    fi
else
    log_info "Gradle was not selected. Skipping."
fi

log_success "Phase 3: Development runtimes phase completed."
