#!/usr/bin/env bash
# bootstrap.sh - Compatibility wrapper for BurnAndBuild Linux orchestrator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/burnandbuild.sh" "$@"
