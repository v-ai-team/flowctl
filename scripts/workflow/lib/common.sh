#!/usr/bin/env bash

# Shared colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

wf_now() { date '+%Y-%m-%d %H:%M:%S'; }
wf_today() { date '+%Y-%m-%d'; }
wf_ensure_dir() { mkdir -p "$1"; }

wf_warn_deprecated() {
  local legacy_name="$1"
  local new_name="$2"
  local key="WF_DEPRECATED_WARNED_${legacy_name//[^a-zA-Z0-9]/_}"
  if [[ "${!key:-0}" == "1" ]]; then
    return 0
  fi
  printf -v "$key" '%s' "1"
  export "$key"
  echo -e "${YELLOW}[deprecation] '${legacy_name}' is kept for compatibility; use '${new_name}' instead.${NC}" >&2
}

# Backward-compatible aliases (Phase 5.2)
now() { wf_warn_deprecated "now" "wf_now"; wf_now "$@"; }
today() { wf_warn_deprecated "today" "wf_today"; wf_today "$@"; }
ensure_dir() { wf_warn_deprecated "ensure_dir" "wf_ensure_dir"; wf_ensure_dir "$@"; }
