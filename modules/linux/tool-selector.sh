#!/usr/bin/env bash
# modules/linux/tool-selector.sh
# Interactive CLI selection menu for BurnAndBuild on Linux

TOOL_IDS=(
    "antigravityCli"
    "antigravityIde"
    "cursor"
    "codex"
    "flutter"
    "android"
    "node"
    "python"
    "docker"
    "java"
    "gradle"
    "gitCli"
    "vscode"
    "notepadpp"
    "chrome"
    "brave"
    "postman"
    "dbeaver"
    "powerbi"
    "jira"
    "baseLinux"
)

TOOL_NAMES=(
    "Antigravity CLI (agy)"
    "Antigravity IDE"
    "Cursor AI Editor"
    "OpenAI Codex CLI"
    "Flutter SDK"
    "Android SDK & Tools"
    "Node.js LTS & npm"
    "Python 3.12 & uv"
    "Docker Engine & Compose"
    "Java JDK 17 (Temurin/OpenJDK)"
    "Gradle Build Tool"
    "Git & Core CLI Suite"
    "Visual Studio Code"
    "Fast Text Editor (Micro/Nano)"
    "Google Chrome"
    "Brave Browser"
    "Postman API Client"
    "DBeaver Community Edition"
    "Power BI Web Integration"
    "Atlassian Jira CLI & Tools"
    "Linux System Optimizations"
)

TOOL_CATS=(
    "AI & Autonomous Agents"
    "AI & Autonomous Agents"
    "AI & Autonomous Agents"
    "AI & Autonomous Agents"
    "Mobile Development"
    "Mobile Development"
    "Web & Backend Runtimes"
    "Web & Backend Runtimes"
    "Containers & Cloud"
    "Languages & SDKs"
    "Languages & SDKs"
    "Core CLI & Shell"
    "IDEs & Code Editors"
    "IDEs & Code Editors"
    "Browsers & Utilities"
    "Browsers & Utilities"
    "API & Database Tools"
    "API & Database Tools"
    "Data & Analytics Tools"
    "Project Management"
    "System Configuration"
)

# Preset definitions (space-separated IDs)
PRESET_AI="baseLinux gitCli node python antigravityCli antigravityIde cursor codex vscode"
PRESET_MOBILE="baseLinux gitCli java android gradle flutter vscode chrome"
PRESET_WEB="baseLinux gitCli node python docker vscode chrome postman"
PRESET_DEVOPS="baseLinux gitCli python docker vscode"
PRESET_MINIMAL="baseLinux gitCli vscode"

# State array of 0 or 1
declare -a SELECTED_FLAGS

init_selection_defaults() {
    local default_ids="antigravityCli antigravityIde cursor codex flutter android node python docker java gradle gitCli vscode chrome baseLinux"
    for i in "${!TOOL_IDS[@]}"; do
        local tid="${TOOL_IDS[$i]}"
        if [[ " $default_ids " =~ [[:space:]]$tid[[:space:]] ]]; then
            SELECTED_FLAGS[$i]=1
        else
            SELECTED_FLAGS[$i]=0
        fi
    done
}

apply_preset_str() {
    local preset_str="$1"
    for i in "${!TOOL_IDS[@]}"; do
        local tid="${TOOL_IDS[$i]}"
        if [[ " $preset_str " =~ [[:space:]]$tid[[:space:]] ]]; then
            SELECTED_FLAGS[$i]=1
        else
            SELECTED_FLAGS[$i]=0
        fi
    done
}

count_selected() {
    local cnt=0
    for s in "${SELECTED_FLAGS[@]}"; do
        if [ "$s" -eq 1 ]; then
            cnt=$((cnt + 1))
        fi
    done
    echo "$cnt"
}

get_selected_tool_ids() {
    local res=()
    for i in "${!TOOL_IDS[@]}"; do
        if [ "${SELECTED_FLAGS[$i]}" -eq 1 ]; then
            res+=("${TOOL_IDS[$i]}")
        fi
    done
    echo "${res[*]}"
}

run_interactive_selector() {
    init_selection_defaults
    local num_tools="${#TOOL_IDS[@]}"

    while true; do
        clear 2>/dev/null || true
        local total_sel
        total_sel=$(count_selected)

        printf "\033[36m================================================================================\033[0m\n"
        printf "\033[1m\033[36m         BURNANDBUILD - DEV ENVIRONMENT TOOL SELECTION MENU (LINUX)\033[0m\n"
        printf "\033[36m================================================================================\033[0m\n"
        printf "\033[90m Toggle any tool number to check/uncheck. Press [ENTER] to start installation.\033[0m\n\n"

        for i in "${!TOOL_IDS[@]}"; do
            local num=$((i + 1))
            local is_sel="${SELECTED_FLAGS[$i]}"
            local mark=" "
            local color="\033[90m"
            local name_color="\033[37m"

            if [ "$is_sel" -eq 1 ]; then
                mark="X"
                color="\033[32m"
                name_color="\033[1m\033[37m"
            fi

            printf "  \033[36m[%2d]\033[0m %b[%s]%b %b%-32s%b \033[34m(%s)\033[0m\n" \
                "$num" "$color" "$mark" "\033[0m" "$name_color" "${TOOL_NAMES[$i]}" "\033[0m" "${TOOL_CATS[$i]}"
        done

        printf "\n\033[36m--------------------------------------------------------------------------------\033[0m\n"
        printf " \033[33mSelected: %d of %d tools\033[0m\n" "$total_sel" "$num_tools"
        printf " \033[35mPresets : [AI] AI & Agents  [M] Mobile  [W] Web  [D] DevOps  [A] All  [C] Clear\033[0m\n"
        printf " \033[32mActions : [Enter] START INSTALLATION   [Q] Quit / Cancel\033[0m\n"
        printf "\033[36m--------------------------------------------------------------------------------\033[0m\n"
        printf "Command / Numbers to toggle (e.g. '1,4,7' or 'AI'): "

        read -r user_input || break
        user_input=$(echo "$user_input" | tr -d '\r' | xargs)
        local lower_input
        lower_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

        if [ -z "$user_input" ] || [ "$lower_input" = "start" ]; then
            if [ "$total_sel" -eq 0 ]; then
                printf "\n\033[31mPlease select at least one tool to continue!\033[0m\n"
                sleep 2
                continue
            fi
            break
        fi

        case "$lower_input" in
            q|exit|quit)
                printf "\n\033[33mSetup cancelled by user.\033[0m\n"
                exit 0
                ;;
            a|all)
                for i in "${!SELECTED_FLAGS[@]}"; do SELECTED_FLAGS[$i]=1; done
                ;;
            c|clear)
                for i in "${!SELECTED_FLAGS[@]}"; do SELECTED_FLAGS[$i]=0; done
                ;;
            ai)
                apply_preset_str "$PRESET_AI"
                ;;
            m|mobile)
                apply_preset_str "$PRESET_MOBILE"
                ;;
            w|web)
                apply_preset_str "$PRESET_WEB"
                ;;
            d|devops)
                apply_preset_str "$PRESET_DEVOPS"
                ;;
            min|minimal)
                apply_preset_str "$PRESET_MINIMAL"
                ;;
            *)
                # Parse comma or space separated numbers
                IFS=', ' read -r -a tokens <<< "$user_input"
                for tok in "${tokens[@]}"; do
                    if [[ "$tok" =~ ^[0-9]+$ ]]; then
                        local idx=$((tok - 1))
                        if [ "$idx" -ge 0 ] && [ "$idx" -lt "$num_tools" ]; then
                            if [ "${SELECTED_FLAGS[$idx]}" -eq 1 ]; then
                                SELECTED_FLAGS[$idx]=0
                            else
                                SELECTED_FLAGS[$idx]=1
                            fi
                        fi
                    fi
                done
                ;;
        esac
    done

    get_selected_tool_ids
}
