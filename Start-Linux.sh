#!/usr/bin/env bash
# Start-Linux.sh - Master launcher for BurnAndBuild Dev Environment Provisioner (Linux)
# Automatically checks for sudo privileges and launches interactive terminal checklist
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/burnandbuild.sh" "$@"
