#!/usr/bin/env bash
# cursor_dispatch.sh — Cursor-native parallel agent dispatch
# Thay thế headless subprocess spawning bằng Spawn Board output
# Compatible với: Cursor 2.4+ (Task tool subagents) + Cursor 3 (Agent Tabs)

# ── Spawn Board Generator ──────────────────────────────────────

cmd_cursor_dispatch() {
  local step
  step=$(wf_require_initialized_workflow)

  # 1. Generate briefs via existing dispatch --dry-run (does NOT spawn processes)
  echo -e "${BLUE}[cursor-dispatch]${NC} Generating briefs..."
  cmd_dispatch --dry-run --headless "$@" 2>/dev/null || true

  # 2. Read generated roles & brief paths
  local dispatch_dir="$REPO_ROOT/workflows/dispatch/step-$step"
  local reports_dir="$dispatch_dir/reports"
  wf_ensure_dir "$reports_dir"

  local step_name
  step_name=$(wf_get_step_name "$step")

  # 3. Collect roles from workflow state
  local roles_json
  roles_json=$(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
s = d['steps']['$step']
roles = [s['agent']] + [r for r in s.get('support_agents',[]) if r != s['agent']]
print(json.dumps(roles))
")

  # 4. Output Spawn Board
  _cursor_spawn_board "$step" "$step_name" "$dispatch_dir" "$reports_dir" "$roles_json"
}

_cursor_spawn_board() {
  local step="$1"
  local step_name="$2"
  local dispatch_dir="$3"
  local reports_dir="$4"
  local roles_json="$5"

  echo ""
  echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}${BOLD}║  🚀 CURSOR SPAWN BOARD — Step $step: $step_name${NC}"
  echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Briefs đã tạo tại: ${CYAN}${dispatch_dir#$REPO_ROOT/}/${NC}"
  echo -e "  Reports sẽ ghi tại: ${CYAN}${reports_dir#$REPO_ROOT/}/${NC}"
  echo ""

  # ── MODE A: Cursor 3 Agent Tabs (visual, user thấy từng agent làm việc) ──
  echo -e "${YELLOW}${BOLD}▶ MODE A — Cursor 3 Agent Tabs (Recommended: thấy từng agent làm việc)${NC}"
  echo -e "  Mở Agents Window: ${BOLD}Cmd+Shift+I${NC} (Mac) / ${BOLD}Ctrl+Shift+I${NC} (Win)"
  echo ""

  local idx=1
  python3 -c "
import json, os
roles = json.loads('$roles_json')
dispatch_dir = '$dispatch_dir'
step = '$step'
repo_root = '$REPO_ROOT'

for role in roles:
    brief_path = os.path.join(dispatch_dir, f'{role}-brief.md')
    report_path = f'workflows/dispatch/step-{step}/reports/{role}-report.md'
    rel_brief   = brief_path.replace(repo_root + '/', '')
    exists = os.path.isfile(brief_path)
    status = '✓' if exists else '⚠ (brief chưa tạo — chạy dispatch trước)'
    print(f'ROLE|{role}|{rel_brief}|{report_path}|{status}')
" | while IFS='|' read -r _ role rel_brief report_path status; do
    echo -e "  ${BOLD}━━━ [Tab $idx] @$role ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Brief:  ${CYAN}$rel_brief${NC} $status"
    echo -e "  Report: ${CYAN}$report_path${NC}"
    echo ""
    echo -e "  ${GREEN}Copy prompt này vào tab mới (sau khi chọn agent '$role'):${NC}"
    echo -e "  ┌────────────────────────────────────────────────────────────┐"
    echo -e "  │ @.cursor/agents/${role}-agent.md                          "
    echo -e "  │ @$rel_brief                                               "
    echo -e "  │ /worker                                                    "
    echo -e "  └────────────────────────────────────────────────────────────┘"
    echo ""
    idx=$((idx + 1))
  done

  # ── MODE B: Cursor Task Tool (inline subagents, tự động không cần mở tay) ──
  echo -e "${YELLOW}${BOLD}▶ MODE B — Task Tool Subagents (Cursor 2.4+, tự động inline)${NC}"
  echo -e "  PM agent dùng Task tool để spawn parallel subagents:"
  echo ""
  python3 -c "
import json, os
roles = json.loads('$roles_json')
dispatch_dir = '$dispatch_dir'
step = '$step'
repo_root = '$REPO_ROOT'

print('  Paste vào PM chat window:')
print()
print('  ---')
for i, role in enumerate(roles):
    brief_path = f'workflows/dispatch/step-{step}/{role}-brief.md'
    print(f'  Spawn subagent @{role}:')
    print(f'    agent_name: {role}')
    print(f'    description: Execute step-{step} tasks as @{role}')
    print(f'    brief_file: {brief_path}')
    print(f'    instructions: Read @{brief_path} and execute. Write report to workflows/dispatch/step-{step}/reports/{role}-report.md')
    if i < len(roles)-1: print()
print('  ---')
"
  echo ""

  # ── PM collect instructions ──
  echo -e "${MAGENTA}${BOLD}━━━ PM: Khi tất cả agents hoàn thành ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Chạy lệnh sau để tổng hợp kết quả:"
  echo -e "  ${BOLD}bash scripts/workflow.sh collect${NC}"
  echo -e "  hoặc gõ ${BOLD}/collect${NC} trong cửa sổ PM"
  echo ""
  echo -e "  Kiểm tra nhanh reports:"
  echo -e "  ${CYAN}ls -la ${reports_dir#$REPO_ROOT/}/${NC}"
  echo ""

  # Write spawn board to file for reference
  local board_file="$dispatch_dir/spawn-board.txt"
  {
    echo "CURSOR SPAWN BOARD — Step $step: $step_name"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Roles: $(python3 -c "import json; print(', '.join(json.loads('$roles_json')))")"
    echo "Brief dir: ${dispatch_dir#$REPO_ROOT/}"
    echo "Report dir: ${reports_dir#$REPO_ROOT/}"
    echo ""
    echo "After all agents complete:"
    echo "  bash scripts/workflow.sh collect"
  } > "$board_file"

  echo -e "  Spawn board đã lưu: ${CYAN}${board_file#$REPO_ROOT/}${NC}"
  echo ""
}
