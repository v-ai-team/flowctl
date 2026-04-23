#!/usr/bin/env bash
# ============================================================
# IT Product Team Workflow — CLI Manager
# Quản lý workflow state, approvals, và transitions
#
# Usage:
#   bash scripts/workflow.sh <command> [args]
#
# Commands:
#   init --project "Name"    Khởi tạo workflow cho project mới
#   status                   Xem trạng thái hiện tại
#   start                    Bắt đầu step hiện tại
#   approve [--by "Name"]    Approve step hiện tại → advance
#   reject "reason"          Reject step với lý do
#   conditional "items"      Approve có điều kiện
#   blocker add "desc"       Thêm blocker
#   blocker resolve <id>     Resolve blocker
#   decision "desc"          Ghi nhận quyết định
#   summary                  In summary của step hiện tại
#   reset <step>             Reset về step cụ thể (cần confirm)
#   history                  Lịch sử approvals
# ============================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$REPO_ROOT/workflow-state.json"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# ── JSON helpers (dùng python3 nếu jq không có) ─────────────
json_get() {
  python3 -c "
import json, sys
data = json.load(open('$STATE_FILE'))
keys = '$1'.split('.')
val = data
for k in keys:
    val = val[k] if isinstance(val, dict) and k in val else None
print(val if val is not None else '')
" 2>/dev/null || echo ""
}

json_set() {
  # $1 = dot-path, $2 = value (string), $3 = type (string|number|null)
  python3 -c "
import json, sys
from datetime import datetime

with open('$STATE_FILE', 'r') as f:
    data = json.load(f)

keys = '$1'.split('.')
obj = data
for k in keys[:-1]:
    obj = obj.setdefault(k, {})

val = '$2'
typ = '${3:-string}'
if typ == 'number':
    obj[keys[-1]] = int(val)
elif typ == 'null' or val == 'null':
    obj[keys[-1]] = None
elif typ == 'bool':
    obj[keys[-1]] = val.lower() == 'true'
else:
    obj[keys[-1]] = val

data['updated_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" 2>/dev/null
}

json_append() {
  # $1 = dot-path to array, $2 = JSON object string
  python3 -c "
import json
from datetime import datetime

with open('$STATE_FILE', 'r') as f:
    data = json.load(f)

keys = '$1'.split('.')
obj = data
for k in keys[:-1]:
    obj = obj[k]

arr = obj.setdefault(keys[-1], [])
arr.append(json.loads('''$2'''))

data['updated_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" 2>/dev/null
}

now() { date '+%Y-%m-%d %H:%M:%S'; }
today() { date '+%Y-%m-%d'; }

# ── Commands ─────────────────────────────────────────────────

cmd_init() {
  local project_name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project_name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$project_name" ]] && {
    echo -n "Tên dự án: "; read -r project_name
  }

  python3 -c "
import json
from datetime import datetime

with open('$STATE_FILE', 'r') as f:
    data = json.load(f)

data['project_name'] = '$project_name'
data['created_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
data['updated_at'] = data['created_at']
data['current_step'] = 1
data['overall_status'] = 'in_progress'
data['steps']['1']['status'] = 'pending'

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

  echo -e "\n${GREEN}${BOLD}Project \"$project_name\" đã được khởi tạo!${NC}"
  echo -e "${CYAN}Step hiện tại: 1 — Requirements Analysis${NC}"
  echo -e "Agent cần dùng: ${YELLOW}@pm${NC} (hỗ trợ: @tech-lead)"
  echo -e "\nBắt đầu bằng: ${BOLD}bash scripts/workflow.sh start${NC}\n"
}

cmd_status() {
  [[ ! -f "$STATE_FILE" ]] && { echo "workflow-state.json không tìm thấy. Chạy: bash setup.sh"; exit 1; }

  local step overall project
  step=$(json_get "current_step")
  overall=$(json_get "overall_status")
  project=$(json_get "project_name")

  echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}   Workflow Status${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  [[ -n "$project" ]] && echo -e "  Project: ${BOLD}$project${NC}"
  echo -e "  Status:  ${YELLOW}$overall${NC}"
  echo ""

  # In tất cả steps
  python3 -c "
import json

with open('$STATE_FILE') as f:
    data = json.load(f)

current = data.get('current_step', 0)
steps = data.get('steps', {})

icons = {
    'completed': '\033[0;32m✓\033[0m',
    'in_progress': '\033[1;33m→\033[0m',
    'approved': '\033[0;32m✓\033[0m',
    'pending': '\033[0;90m○\033[0m',
    'rejected': '\033[0;31m✗\033[0m',
}

for n in range(1, 10):
    s = steps.get(str(n), {})
    name = s.get('name', '')
    status = s.get('status', 'pending')
    agent = s.get('agent', '')
    icon = icons.get(status, '○')

    prefix = '  '
    if n == current:
        prefix = '\033[1m→ \033[0m'

    approval = ''
    if s.get('approval_status'):
        approval = f\" [{s['approval_status'].upper()}]\"

    print(f'{prefix}{icon} Step {n}: {name} (@{agent}){approval}')
"

  echo ""

  # Blockers
  python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
step = str(data.get('current_step', 1))
blockers = data.get('steps', {}).get(step, {}).get('blockers', [])
open_blockers = [b for b in blockers if not b.get('resolved')]
if open_blockers:
    print(f'\033[0;31m  Blockers ({len(open_blockers)}):\033[0m')
    for i, b in enumerate(open_blockers):
        print(f'    [{i}] {b.get(\"description\", \"\")}')
    print()
"

  echo -e "  Dùng ${CYAN}bash scripts/workflow.sh approve${NC} sau khi step hoàn thành\n"
}

cmd_start() {
  local step
  step=$(json_get "current_step")
  [[ -z "$step" || "$step" == "0" ]] && {
    echo -e "${YELLOW}Workflow chưa được khởi tạo. Chạy: bash scripts/workflow.sh init${NC}"
    exit 1
  }

  json_set "steps.$step.status" "in_progress"
  json_set "steps.$step.started_at" "$(now)"

  local name agent
  name=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$step']['name'])")
  agent=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$step']['agent'])")

  echo -e "\n${GREEN}${BOLD}Step $step — $name đã bắt đầu${NC}"
  echo -e "Agent chính: ${YELLOW}@$agent${NC}"
  echo -e "\nKhởi động Graphify context:"
  echo -e "  ${CYAN}graphify_query(\"step:$step:context\")${NC}"
  echo -e "  ${CYAN}gitnexus_get_architecture()${NC}"
  echo -e "\nXem agent guide: ${BOLD}.cursor/agents/${agent}-agent.md${NC}\n"
}

cmd_approve() {
  local by="${2:-Human}"
  local step
  step=$(json_get "current_step")
  local name
  name=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$step']['name'])")

  json_set "steps.$step.status" "completed"
  json_set "steps.$step.approval_status" "approved"
  json_set "steps.$step.completed_at" "$(now)"
  json_set "steps.$step.approved_at" "$(now)"
  json_set "steps.$step.approved_by" "$by"

  # Advance to next step
  local next_step=$((step + 1))
  if [[ $next_step -le 9 ]]; then
    json_set "current_step" "$next_step" "number"
    local next_name next_agent
    next_name=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$next_step']['name'])")
    next_agent=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$next_step']['agent'])")

    echo -e "\n${GREEN}${BOLD}✓ Step $step — $name: APPROVED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\n${CYAN}${BOLD}→ Tiếp theo: Step $next_step — $next_name${NC}"
    echo -e "Agent: ${YELLOW}@$next_agent${NC}"
    echo -e "Bắt đầu: ${BOLD}bash scripts/workflow.sh start${NC}\n"
  else
    json_set "overall_status" "completed"
    echo -e "\n${GREEN}${BOLD}🎉 WORKFLOW HOÀN THÀNH! Project đã release.${NC}\n"
  fi
}

cmd_reject() {
  local reason="${2:-Không có lý do}"
  local step
  step=$(json_get "current_step")
  local name
  name=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['steps']['$step']['name'])")

  json_set "steps.$step.approval_status" "rejected"
  json_set "steps.$step.status" "in_progress"

  # Append rejection note
  json_append "steps.$step.decisions" "{\"type\": \"rejection\", \"reason\": \"$reason\", \"date\": \"$(today)\"}"

  echo -e "\n${RED}${BOLD}✗ Step $step — $name: REJECTED${NC}"
  echo -e "Lý do: $reason"
  echo -e "\nAddress concerns rồi chạy lại: ${BOLD}bash scripts/workflow.sh approve${NC}\n"
}

cmd_add_blocker() {
  local desc="${2:-}"
  [[ -z "$desc" ]] && { echo -n "Mô tả blocker: "; read -r desc; }

  local step
  step=$(json_get "current_step")
  local id="B$(date +%Y%m%d%H%M%S)"

  json_append "steps.$step.blockers" "{\"id\": \"$id\", \"description\": \"$desc\", \"created_at\": \"$(now)\", \"resolved\": false}"

  # Update metrics
  python3 -c "
import json
with open('$STATE_FILE') as f: d = json.load(f)
d['metrics']['total_blockers'] = d['metrics'].get('total_blockers', 0) + 1
with open('$STATE_FILE', 'w') as f: json.dump(d, f, indent=2, ensure_ascii=False)
"

  echo -e "\n${YELLOW}Blocker đã được ghi nhận: [$id] $desc${NC}"
  echo -e "Resolve: ${BOLD}bash scripts/workflow.sh blocker resolve $id${NC}\n"
}

cmd_resolve_blocker() {
  local id="${2:-}"
  [[ -z "$id" ]] && { echo "Usage: blocker resolve <id>"; exit 1; }

  local step
  step=$(json_get "current_step")

  python3 -c "
import json
from datetime import datetime

with open('$STATE_FILE') as f:
    data = json.load(f)

step = str(data.get('current_step', 1))
blockers = data.get('steps', {}).get(step, {}).get('blockers', [])
for b in blockers:
    if b.get('id') == '$id':
        b['resolved'] = True
        b['resolved_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print('Blocker $id đã được resolved')
"
}

cmd_add_decision() {
  local desc="${2:-}"
  [[ -z "$desc" ]] && { echo -n "Quyết định: "; read -r desc; }

  local step
  step=$(json_get "current_step")
  local id="D$(date +%Y%m%d%H%M%S)"

  json_append "steps.$step.decisions" "{\"id\": \"$id\", \"description\": \"$desc\", \"date\": \"$(today)\"}"

  python3 -c "
import json
with open('$STATE_FILE') as f: d = json.load(f)
d['metrics']['total_decisions'] = d['metrics'].get('total_decisions', 0) + 1
with open('$STATE_FILE', 'w') as f: json.dump(d, f, indent=2, ensure_ascii=False)
"

  echo -e "${GREEN}Quyết định đã được ghi nhận: [$id]${NC}\n"
}

cmd_summary() {
  local step
  step=$(json_get "current_step")

  python3 -c "
import json

with open('$STATE_FILE') as f:
    data = json.load(f)

step = str(data.get('current_step', 1))
s = data['steps'].get(step, {})

print(f'''
\033[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step {step} Summary: {s.get(\"name\", \"\")}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
Agent:      @{s.get(\"agent\", \"\")}
Status:     {s.get(\"status\", \"pending\")}
Started:    {s.get(\"started_at\", \"—\")}
Completed:  {s.get(\"completed_at\", \"—\")}
Approval:   {s.get(\"approval_status\", \"pending\")}

Deliverables ({len(s.get(\"deliverables\", []))}):''')

for d in s.get('deliverables', []):
    print(f'  ✓ {d}')

blockers = s.get('blockers', [])
open_b = [b for b in blockers if not b.get('resolved')]
print(f'\nBlockers: {len(blockers)} total, {len(open_b)} open')
for b in open_b:
    print(f'  ! {b.get(\"description\", \"\")}')

decisions = s.get('decisions', [])
print(f'\nDecisions ({len(decisions)}):')
for d in decisions:
    if d.get('type') != 'rejection':
        print(f'  → {d.get(\"description\", \"\")}')

print()
"
}

cmd_history() {
  python3 -c "
import json

with open('$STATE_FILE') as f:
    data = json.load(f)

print(f'\033[1mApproval History — {data.get(\"project_name\", \"Project\")}\033[0m')
print()

for n in range(1, 10):
    s = data['steps'].get(str(n), {})
    status = s.get('approval_status')
    if status:
        icon = '✓' if status == 'approved' else ('✗' if status == 'rejected' else '~')
        color = '\033[0;32m' if status == 'approved' else ('\033[0;31m' if status == 'rejected' else '\033[1;33m')
        print(f'  {color}{icon}\033[0m Step {n}: {s.get(\"name\",\"\")} — {status.upper()} by {s.get(\"approved_by\", \"?\")} @ {s.get(\"approved_at\", \"?\")}')
print()
"
}

cmd_reset() {
  local target="${2:-}"
  [[ -z "$target" ]] && { echo "Usage: reset <step_number>"; exit 1; }

  echo -e "${RED}${BOLD}CẢNH BÁO: Reset workflow về Step $target.${NC}"
  echo -e "Tất cả progress từ Step $target trở đi sẽ bị xóa."
  echo -n "Xác nhận? (yes/no): "
  read -r confirm
  [[ "$confirm" != "yes" ]] && { echo "Hủy."; exit 0; }

  python3 -c "
import json
from datetime import datetime

with open('$STATE_FILE') as f:
    data = json.load(f)

target = int('$target')
data['current_step'] = target
data['overall_status'] = 'in_progress'

for n in range(target, 10):
    s = data['steps'].get(str(n), {})
    s['status'] = 'pending'
    s['started_at'] = None
    s['completed_at'] = None
    s['approved_at'] = None
    s['approved_by'] = None
    s['approval_status'] = None
    s['deliverables'] = []
    s['blockers'] = []
    s['decisions'] = []

data['updated_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f'Workflow đã reset về Step $target')
"
}

# ── Main dispatcher ──────────────────────────────────────────
CMD="${1:-status}"
shift || true

case "$CMD" in
  init)         cmd_init "$@" ;;
  status|s)     cmd_status ;;
  start)        cmd_start ;;
  approve|a)    cmd_approve "$@" ;;
  reject|r)     cmd_reject "$@" ;;
  conditional)  cmd_reject "$@" ;;
  blocker)
    SUBCMD="${1:-}"; shift || true
    case "$SUBCMD" in
      add)     cmd_add_blocker "$@" ;;
      resolve) cmd_resolve_blocker "$@" ;;
      *)       echo "Usage: blocker [add|resolve]" ;;
    esac
    ;;
  decision|d)   cmd_add_decision "$@" ;;
  summary|sum)  cmd_summary ;;
  history|h)    cmd_history ;;
  reset)        cmd_reset "$@" ;;
  help|--help|-h)
    echo -e "\n${BOLD}IT Product Workflow CLI${NC}"
    echo -e "  init --project \"Name\"  Khởi tạo dự án mới"
    echo -e "  status                 Xem trạng thái"
    echo -e "  start                  Bắt đầu step hiện tại"
    echo -e "  approve [--by Name]    Approve và advance"
    echo -e "  reject \"reason\"        Reject với lý do"
    echo -e "  blocker add \"desc\"     Thêm blocker"
    echo -e "  blocker resolve <id>   Resolve blocker"
    echo -e "  decision \"desc\"        Ghi nhận quyết định"
    echo -e "  summary                Step summary"
    echo -e "  history                Lịch sử approvals"
    echo -e "  reset <step>           Reset về step cụ thể\n"
    ;;
  *)
    echo "Unknown command: $CMD. Dùng --help để xem danh sách lệnh."
    exit 1
    ;;
esac
