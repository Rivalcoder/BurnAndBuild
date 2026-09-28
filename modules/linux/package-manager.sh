#!/usr/bin/env bash
# modules/linux/package-manager.sh
# Cross-distribution Linux package manager abstraction for BurnAndBuild

PKG_MANAGER=""
PKG_UPDATE_CMD=""
PKG_INSTALL_CMD=""
PKG_CHECK_CMD=""

detect_distro_and_pm() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_LIKE="${ID_LIKE:-$ID}"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE="unknown"
    fi

    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_UPDATE_CMD="apt-get update -y"
        PKG_INSTALL_CMD="DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends"
        PKG_CHECK_CMD="dpkg -s"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_UPDATE_CMD="dnf check-update -y || true"
        PKG_INSTALL_CMD="dnf install -y"
        PKG_CHECK_CMD="rpm -q"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_UPDATE_CMD="yum check-update -y || true"
        PKG_INSTALL_CMD="yum install -y"
        PKG_CHECK_CMD="rpm -q"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_UPDATE_CMD="pacman -Sy --noconfirm"
        PKG_INSTALL_CMD="pacman -S --noconfirm --needed"
        PKG_CHECK_CMD="pacman -Q"
    else
        PKG_MANAGER="generic"
    fi
}

detect_distro_and_pm

pm_update() {
    log_info "Updating system package repositories via $PKG_MANAGER..."
    eval "$PKG_UPDATE_CMD" >/dev/null 2>&1 || true
}

pm_install() {
    local packages=("$@")
    if [ "${#packages[@]}" -eq 0 ]; then
        return 0
    fi
    log_info "Installing package(s): ${packages[*]}..."
    eval "$PKG_INSTALL_CMD ${packages[*]}"
}

pm_is_installed() {
    local pkg="$1"
    if [ -z "$pkg" ]; then return 1; fi
    case "$PKG_MANAGER" in
        apt)
            dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"
            return $?
            ;;
        dnf|yum)
            rpm -q "$pkg" >/dev/null 2>&1
            return $?
            ;;
        pacman)
            pacman -Q "$pkg" >/dev/null 2>&1
            return $?
            ;;
        *)
            command -v "$pkg" >/dev/null 2>&1
            return $?
            ;;
    esac
}

ensure_command() {
    local cmd="$1"
    local fallback_pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_info "Command '$cmd' not found. Installing via '$fallback_pkg'..."
        pm_install "$fallback_pkg"
    fi
}
