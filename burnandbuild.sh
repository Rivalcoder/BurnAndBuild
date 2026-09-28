#!/usr/bin/env bash
# burnandbuild.sh
# Master Orchestrator for BurnAndBuild on Linux
# Supports both Interactive Terminal Checklist & Unattended Command-Line Flags

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Help Check before elevation
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
BurnAndBuild - Disposable Dev Environment Automation (Linux)

Usage:
  sudo ./burnandbuild.sh [OPTIONS]

Options:
  -t, --tools <list>       Comma or space-separated list of tool IDs to install
  -p, --preset <name>      Predefined profile: 'ai', 'mobile', 'web', 'devops', 'minimal', or 'all'
  -f, --full               Install all tools without interactive prompting
      --no-gui, --cli      Force interactive terminal menu
      --base-only          Install only base Linux optimizations and CLI tools
      --git-name <name>    Set Git global user name
      --git-email <email>  Set Git global user email
      --config <path>      Path to config.json
  -h, --help               Display this help message

Presets:
  ai       Antigravity CLI/IDE, Cursor, Codex, Git, Node.js, Python, VS Code
  mobile   Flutter, Android SDK, Java 17, Gradle, Git, VS Code, Chrome
  web      Node.js, Python, Docker, Git, VS Code, Chrome, Postman
  devops   Docker, Python, Git, VS Code
  minimal  Base Linux, Git, VS Code

Examples:
  sudo ./burnandbuild.sh                      # Interactive menu
  sudo ./burnandbuild.sh --preset ai          # Unattended AI preset
  sudo ./burnandbuild.sh --full               # Full development catalog
EOF
    exit 0
fi

# 1. Administrator Elevation Check & Self-Elevation
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        echo "Administrator (sudo) privileges required. Elevating..."
        exec sudo -E "$0" "$@"
    else
        echo "Error: This script must be run as root or with sudo." >&2
        exit 1
    fi
fi

# 2. Source Core Modules
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/linux/logging.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/linux/package-manager.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/linux/tool-selector.sh"

# 3. Argument Parsing
EXPLICIT_TOOLS=""
PRESET=""
FULL=0
NO_GUI=0
BASE_ONLY=0
GIT_NAME=""
GIT_EMAIL=""
CONFIG_PATH="$SCRIPT_DIR/config.json"

show_help() {
    cat << EOF
BurnAndBuild - Disposable Dev Environment Automation (Linux)

Usage:
  sudo ./burnandbuild.sh [OPTIONS]

Options:
  -t, --tools <list>       Comma or space-separated list of tool IDs to install
  -p, --preset <name>      Predefined profile: 'ai', 'mobile', 'web', 'devops', 'minimal', or 'all'
  -f, --full               Install all tools without interactive prompting
      --no-gui, --cli      Force interactive terminal menu
      --base-only          Install only base Linux optimizations and CLI tools
      --git-name <name>    Set Git global user name
      --git-email <email>  Set Git global user email
      --config <path>      Path to config.json
  -h, --help               Display this help message

Presets:
  ai       Antigravity CLI/IDE, Cursor, Codex, Git, Node.js, Python, VS Code
  mobile   Flutter, Android SDK, Java 17, Gradle, Git, VS Code, Chrome
  web      Node.js, Python, Docker, Git, VS Code, Chrome, Postman
  devops   Docker, Python, Git, VS Code
  minimal  Base Linux, Git, VS Code

Examples:
  sudo ./burnandbuild.sh                      # Interactive menu
  sudo ./burnandbuild.sh --preset ai          # Unattended AI preset
  sudo ./burnandbuild.sh --full               # Full development catalog
EOF
    exit 0
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -t|--tools)
            EXPLICIT_TOOLS="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        -f|--full)
            FULL=1
            shift
            ;;
        --no-gui|--cli)
            NO_GUI=1
            shift
            ;;
        --base-only)
            BASE_ONLY=1
            shift
            ;;
        --git-name)
            GIT_NAME="$2"
            shift 2
            ;;
        --git-email)
            GIT_EMAIL="$2"
            shift 2
            ;;
        --config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_warn "Unknown argument: $1"
            shift
            ;;
    esac
done

# 4. Display Banner
OS_NAME="$(uname -s) $(uname -r)"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="$PRETTY_NAME"
fi

printf "\033[36m================================================================================\033[0m\n"
printf "\033[1m\033[36m          BURNANDBUILD - DISPOSABLE DEV ENVIRONMENT ORCHESTRATOR\033[0m\n"
printf "\033[36m================================================================================\033[0m\n"
printf "  Target OS       : %s\n" "$OS_NAME"
printf "  Architecture    : %s\n" "$(uname -m)"
printf "  Package Manager : %s\n" "$PKG_MANAGER"
printf "  Log File        : %s\n" "$LOG_FILE"
printf "\033[36m================================================================================\033[0m\n"

# 5. Resolve Selected Tools
SELECTED_TOOLS=()

if [ "$BASE_ONLY" -eq 1 ]; then
    SELECTED_TOOLS=("baseLinux" "gitCli")
elif [ -n "$EXPLICIT_TOOLS" ]; then
    IFS=', ' read -r -a SELECTED_TOOLS <<< "$EXPLICIT_TOOLS"
elif [ "$FULL" -eq 1 ]; then
    SELECTED_TOOLS=("${TOOL_IDS[@]}")
elif [ -n "$PRESET" ]; then
    case "$(echo "$PRESET" | tr '[:upper:]' '[:lower:]')" in
        ai)
            IFS=' ' read -r -a SELECTED_TOOLS <<< "$PRESET_AI"
            ;;
        mobile)
            IFS=' ' read -r -a SELECTED_TOOLS <<< "$PRESET_MOBILE"
            ;;
        web)
            IFS=' ' read -r -a SELECTED_TOOLS <<< "$PRESET_WEB"
            ;;
        devops)
            IFS=' ' read -r -a SELECTED_TOOLS <<< "$PRESET_DEVOPS"
            ;;
        minimal)
            IFS=' ' read -r -a SELECTED_TOOLS <<< "$PRESET_MINIMAL"
            ;;
        all)
            SELECTED_TOOLS=("${TOOL_IDS[@]}")
            ;;
        *)
            log_error "Unknown preset: $PRESET"
            exit 1
            ;;
    esac
elif [ -t 0 ] || [ "$NO_GUI" -eq 1 ]; then
    # Interactive TTY Selection
    interactive_res=$(run_interactive_selector)
    IFS=' ' read -r -a SELECTED_TOOLS <<< "$interactive_res"
else
    # Non-interactive default: All tools
    SELECTED_TOOLS=("${TOOL_IDS[@]}")
fi

if [ "${#SELECTED_TOOLS[@]}" -eq 0 ]; then
    log_warn "No tools selected for installation. Exiting."
    exit 0
fi

log_info "Selected tools for installation: ${SELECTED_TOOLS[*]}"
START_TIME=$(date +%s)

# Helper function
tool_selected() {
    local target="$1"
    for t in "${SELECTED_TOOLS[@]}"; do
        if [ "$t" = "$target" ]; then return 0; fi
    done
    return 1
}

# 6. Execute Provisioning Pipeline
# Phase 1: Base Linux
if tool_selected "baseLinux" || tool_selected "baseWindows"; then
    bash "$SCRIPT_DIR/scripts/linux/01-base-linux.sh"
else
    log_info "Phase 1 (Base Linux) skipped per tool selection."
fi

# Phase 2: Core CLI
if tool_selected "gitCli"; then
    bash "$SCRIPT_DIR/scripts/linux/02-common-cli.sh"
else
    log_info "Phase 2 (Core CLI) skipped per tool selection."
fi

# Phase 3: Runtimes (Java, Node, Python, Gradle)
RUNTIMES_TO_RUN=()
for r in "java" "node" "python" "gradle"; do
    if tool_selected "$r"; then RUNTIMES_TO_RUN+=("$r"); fi
done
if [ "${#RUNTIMES_TO_RUN[@]}" -gt 0 ]; then
    bash "$SCRIPT_DIR/scripts/linux/03-runtimes.sh" "${RUNTIMES_TO_RUN[@]}"
else
    log_info "Phase 3 (Runtimes) skipped: none selected."
fi

# Phase 4: Android SDK
if tool_selected "android"; then
    bash "$SCRIPT_DIR/scripts/linux/04-android-sdk.sh"
else
    log_info "Phase 4 (Android SDK) skipped per tool selection."
fi

# Phase 5: Flutter SDK
if tool_selected "flutter"; then
    bash "$SCRIPT_DIR/scripts/linux/05-flutter-sdk.sh"
else
    log_info "Phase 5 (Flutter SDK) skipped per tool selection."
fi

# Phase 6: Docker
if tool_selected "docker"; then
    bash "$SCRIPT_DIR/scripts/linux/06-docker.sh"
else
    log_info "Phase 6 (Docker) skipped per tool selection."
fi

# Phase 7: IDEs & Editors
IDES_TO_RUN=()
for id in "vscode" "notepadpp" "chrome" "brave" "postman" "dbeaver" "powerbi" "jira"; do
    if tool_selected "$id"; then IDES_TO_RUN+=("$id"); fi
done
if [ "${#IDES_TO_RUN[@]}" -gt 0 ]; then
    bash "$SCRIPT_DIR/scripts/linux/07-ides-editors.sh" "${IDES_TO_RUN[@]}"
else
    log_info "Phase 7 (IDEs & Editors) skipped per tool selection."
fi

# Phase 8: AI Tools (Antigravity CLI/IDE, Cursor, Codex)
AI_TO_RUN=()
for ai in "antigravityCli" "antigravityIde" "cursor" "codex"; do
    if tool_selected "$ai"; then AI_TO_RUN+=("$ai"); fi
done
if [ "${#AI_TO_RUN[@]}" -gt 0 ]; then
    bash "$SCRIPT_DIR/scripts/linux/08-ai-tools.sh" "${AI_TO_RUN[@]}"
else
    log_info "Phase 8 (AI Tools) skipped per tool selection."
fi

# Phase 9: Shell Profile & Aliases
bash "$SCRIPT_DIR/scripts/linux/09-shell-profile.sh"

# Phase 10: Persistence, SSH & Git
bash "$SCRIPT_DIR/scripts/linux/10-persistence-setup.sh" "$GIT_NAME" "$GIT_EMAIL"

END_TIME=$(date +%s)
DURATION=$(( (END_TIME - START_TIME) / 60 ))

echo ""
printf "\033[32m================================================================================\033[0m\n"
log_success "BURNANDBUILD DEV ENVIRONMENT SETUP COMPLETED IN $DURATION MINUTES!"
printf "\033[32m================================================================================\033[0m\n\n"

# Run Verification Smoke Test
if [ -f "$SCRIPT_DIR/tests/verify-installation.sh" ]; then
    bash "$SCRIPT_DIR/tests/verify-installation.sh" "${SELECTED_TOOLS[@]}" || true
fi
