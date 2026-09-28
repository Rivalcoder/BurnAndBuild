#!/usr/bin/env bash
# tests/verify-installation.sh
# Automated validation smoke test for BurnAndBuild on Linux
# Dynamically verifies installed tools, versions, and paths

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source logging
# shellcheck disable=SC1091
source "$ROOT_DIR/modules/linux/logging.sh" 2>/dev/null || true

log_header "BurnAndBuild - Environment Verification & Health Check (Linux)"

FILTER_TOOLS=("$@")
should_check() {
    local tid="$1"
    if [ "${#FILTER_TOOLS[@]}" -eq 0 ]; then return 0; fi
    for t in "${FILTER_TOOLS[@]}"; do
        if [ "$t" = "$tid" ]; then return 0; fi
    done
    return 1
}

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

check_cmd() {
    local comp_name="$1"
    local tool_id="$2"
    local cmd="$3"
    local ver_cmd="${4:-$cmd --version}"

    if ! should_check "$tool_id"; then return 0; fi
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if command -v "$cmd" >/dev/null 2>&1; then
        local ver_output
        ver_output=$(eval "$ver_cmd" 2>&1 | head -n 1 | tr -d '\r')
        printf "  \033[32m[PASS]\033[0m %-30s : %s\n" "$comp_name" "$ver_output"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "  \033[31m[FAIL]\033[0m %-30s : Command '%s' not found in PATH\n" "$comp_name" "$cmd"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

check_path() {
    local comp_name="$1"
    local tool_id="$2"
    local path_to_check="$3"

    if ! should_check "$tool_id"; then return 0; fi
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if [ -e "$path_to_check" ]; then
        printf "  \033[32m[PASS]\033[0m %-30s : %s\n" "$comp_name" "$path_to_check"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "  \033[31m[FAIL]\033[0m %-30s : Path not found '%s'\n" "$comp_name" "$path_to_check"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo ""
printf "\033[1m%-38s %s\033[0m\n" "COMPONENT" "STATUS & DETAILS"
echo "--------------------------------------------------------------------------------"

# 1. Base OS
check_path "Workspace Directory" "baseLinux" "/workspace"

# 2. Core CLI
check_cmd "Git Version Control" "gitCli" "git"
check_cmd "GitHub CLI" "gitCli" "gh"
check_cmd "jq JSON Processor" "gitCli" "jq"
check_cmd "Ripgrep Fast Search" "gitCli" "rg"
check_cmd "fzf Fuzzy Finder" "gitCli" "fzf"

# 3. Runtimes
check_cmd "Java Runtime (JDK 17)" "java" "java" "java -version 2>&1 | head -n 1"
check_cmd "Node.js Runtime" "node" "node"
check_cmd "npm Package Manager" "node" "npm"
check_cmd "Python Interpreter" "python" "python3"
check_cmd "Astral uv Package Manager" "python" "uv"
check_cmd "Gradle Build Tool" "gradle" "gradle" "gradle --version | head -n 3 | tr '\n' ' '"

# 4. Mobile SDKs
check_cmd "Android Platform Tools (adb)" "android" "adb"
check_path "Android SDK Directory" "android" "/opt/android-sdk"
check_cmd "Flutter SDK" "flutter" "flutter"
check_cmd "Dart SDK" "flutter" "dart"

# 5. Containers
check_cmd "Docker Engine" "docker" "docker"
check_cmd "Docker Compose" "docker" "docker" "docker compose version"

# 6. IDEs & Editors
check_cmd "Visual Studio Code" "vscode" "code"
check_cmd "Google Chrome" "chrome" "google-chrome" "google-chrome --version"

# 7. AI & Autonomous Agent Tools
check_cmd "Google Antigravity CLI (agy)" "antigravityCli" "agy"
check_path "Antigravity IDE Directory" "antigravityIde" "/opt/antigravity-ide"
check_cmd "Cursor AI Editor" "cursor" "cursor" "cursor --version 2>&1 || echo 'Present'"
check_cmd "OpenAI Codex CLI" "codex" "codex"

echo "--------------------------------------------------------------------------------"
printf "Verification Complete: \033[32m%d Passed\033[0m, \033[31m%d Failed\033[0m out of %d components.\n\n" \
    "$PASS_COUNT" "$FAIL_COUNT" "$TOTAL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
