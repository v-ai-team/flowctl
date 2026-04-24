#!/usr/bin/env bash
# Backward-compatible entrypoint — delegates to workflow engine.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/workflow.sh" "$@"
