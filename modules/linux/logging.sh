#!/usr/bin/env bash
# modules/linux/logging.sh
# Enterprise-grade logging library for BurnAndBuild on Linux
# Supports colored terminal output and persistent timestamped log files

LOG_DIR="/var/log/burnandbuild"
if [ ! -w "/var/log" ] && [ "$EUID" -ne 0 ]; then
    LOG_DIR="$HOME/.burnandbuild/logs"
fi

mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp/burnandbuild-logs"
mkdir -p "$LOG_DIR" 2>/dev/null

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/burnandbuild-$TIMESTAMP.log"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/burnandbuild-$TIMESTAMP.log"

# Color Codes
COLOR_RESET="\033[0m"
COLOR_GRAY="\033[90m"
COLOR_CYAN="\033[36m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_MAGENTA="\033[35m"
COLOR_BOLD="\033[1m"

_write_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local time_str
    time_str=$(date +"%Y-%m-%d %H:%M:%S")

    # Console output
    printf "${COLOR_GRAY}[%s]${COLOR_RESET} ${color}[%-7s]${COLOR_RESET} %b\n" "$time_str" "$level" "$message"

    # File output (strip ANSI escape codes)
    if [ -n "$LOG_FILE" ] && [ -w "$LOG_FILE" ]; then
        local clean_msg
        clean_msg=$(printf "%b" "$message" | sed 's/\x1b\[[0-9;]*m//g')
        printf "[%s] [%-7s] %s\n" "$time_str" "$level" "$clean_msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_info() {
    _write_log "INFO" "$COLOR_CYAN" "$*"
}

log_warn() {
    _write_log "WARN" "$COLOR_YELLOW" "$*"
}

log_error() {
    _write_log "ERROR" "$COLOR_RED" "$*"
}

log_success() {
    _write_log "SUCCESS" "$COLOR_GREEN" "$*"
}

log_step() {
    _write_log "STEP" "$COLOR_MAGENTA" "$*"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        _write_log "DEBUG" "$COLOR_GRAY" "$*"
    fi
}

log_header() {
    local title="$1"
    local time_str
    time_str=$(date +"%Y-%m-%d %H:%M:%S")
    echo ""
    printf "${COLOR_CYAN}================================================================================${COLOR_RESET}\n"
    printf "${COLOR_BOLD}${COLOR_CYAN}  %s${COLOR_RESET}\n" "$title"
    printf "${COLOR_CYAN}================================================================================${COLOR_RESET}\n"
    if [ -n "$LOG_FILE" ] && [ -w "$LOG_FILE" ]; then
        printf "\n================================================================================\n  %s\n================================================================================\n" "$title" >> "$LOG_FILE" 2>/dev/null || true
    fi
}
