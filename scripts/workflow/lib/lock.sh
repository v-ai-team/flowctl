#!/usr/bin/env bash

wf_acquire_workflow_lock() {
  if mkdir "$WORKFLOW_LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$WORKFLOW_LOCK_DIR/pid"
    trap wf_release_workflow_lock EXIT
    return 0
  fi

  local holder="unknown"
  if [[ -f "$WORKFLOW_LOCK_DIR/pid" ]]; then
    holder="$(<"$WORKFLOW_LOCK_DIR/pid")"
  fi
  if [[ "$holder" =~ ^[0-9]+$ ]]; then
    if ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$WORKFLOW_LOCK_DIR" 2>/dev/null || true
      if mkdir "$WORKFLOW_LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$WORKFLOW_LOCK_DIR/pid"
        trap wf_release_workflow_lock EXIT
        echo -e "${YELLOW}Reclaimed stale workflow lock from pid=$holder.${NC}"
        return 0
      fi
      local new_holder="unknown"
      if [[ -f "$WORKFLOW_LOCK_DIR/pid" ]]; then
        new_holder="$(<"$WORKFLOW_LOCK_DIR/pid")"
      fi
      echo -e "${RED}Workflow lock đang được giữ bởi pid=$new_holder. Thử lại sau.${NC}"
      exit 1
    fi
  fi
  echo -e "${RED}Workflow lock đang được giữ bởi pid=$holder. Thử lại sau.${NC}"
  exit 1
}

wf_release_workflow_lock() {
  rm -rf "$WORKFLOW_LOCK_DIR" 2>/dev/null || true
}

# Backward-compatible aliases (Phase 5.2)
acquire_workflow_lock() { wf_warn_deprecated "acquire_workflow_lock" "wf_acquire_workflow_lock"; wf_acquire_workflow_lock "$@"; }
release_workflow_lock() { wf_warn_deprecated "release_workflow_lock" "wf_release_workflow_lock"; wf_release_workflow_lock "$@"; }
