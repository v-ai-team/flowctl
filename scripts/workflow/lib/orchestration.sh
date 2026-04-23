#!/usr/bin/env bash

cmd_team() {
  local action="${1:-status}"
  shift || true

  local step
  step=$(wf_require_initialized_workflow)
  local step_status
  step_status=$(wf_json_get "steps.$step.status")
  local step_name
  step_name=$(wf_get_step_name "$step")
  local role_list
  role_list=$(wf_get_step_roles_csv "$step")
  local dispatch_dir="$REPO_ROOT/workflows/dispatch/step-$step"
  local reports_dir="$dispatch_dir/reports"
  local logs_dir="$dispatch_dir/logs"

  case "$action" in
    start|delegate)
      echo -e "\n${BLUE}${BOLD}[TEAM] PM step-based delegate${NC}"
      echo -e "Current step: ${BOLD}$step — $step_name${NC}"
      echo -e "Spawn roles: ${YELLOW}${role_list}${NC}"
      if [[ "$step_status" == "pending" ]]; then
        echo -e "Step đang pending, auto start step trước khi delegate..."
        cmd_start
      fi
      echo -e "Dispatch workers headless..."
      cmd_dispatch --headless "$@"
      ;;
    sync)
      echo -e "\n${BLUE}${BOLD}[TEAM] PM sync${NC}"
      cmd_collect
      cmd_summary
      ;;
    status)
      echo -e "\n${BLUE}${BOLD}[TEAM] PM status${NC}"
      cmd_summary
      echo -e "Dispatch dir: ${BOLD}${dispatch_dir#$REPO_ROOT/}${NC}"
      local report_count log_count
      report_count=$(find "$reports_dir" -maxdepth 1 -type f -name "*-report.md" 2>/dev/null | wc -l | tr -d ' ')
      log_count=$(find "$logs_dir" -maxdepth 1 -type f -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
      echo -e "Reports: ${report_count:-0}"
      echo -e "Logs: ${log_count:-0}"
      echo ""
      ;;
    monitor)
      local stale_seconds="300"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --stale-seconds)
            stale_seconds="${2:-300}"
            shift 2
            ;;
          *)
            echo -e "${RED}Unknown option for team monitor: $1${NC}"
            echo -e "Usage: bash scripts/workflow.sh team monitor [--stale-seconds N]\n"
            exit 1
            ;;
        esac
      done
      [[ "$stale_seconds" =~ ^[0-9]+$ ]] || stale_seconds="300"
      echo -e "\n${BLUE}${BOLD}[TEAM] PM monitor${NC}"
      python3 - <<PY
import json
import os
import calendar
import time
from pathlib import Path

state = json.loads(Path("$STATE_FILE").read_text(encoding="utf-8"))
step = str($step)
repo_root = Path("$REPO_ROOT")
dispatch_dir = repo_root / "workflows" / "dispatch" / f"step-{step}"
reports_dir = dispatch_dir / "reports"
logs_dir = dispatch_dir / "logs"
idem_path = Path("$IDEMPOTENCY_FILE")
sessions_path = Path("$ROLE_SESSIONS_FILE")
heartbeats_path = Path("$HEARTBEATS_FILE")
stale_seconds = int("$stale_seconds")
now_ts = time.time()

idem = json.loads(idem_path.read_text(encoding="utf-8")) if idem_path.exists() else {}
sessions = json.loads(sessions_path.read_text(encoding="utf-8")) if sessions_path.exists() else {}
latest_hb_by_role = {}
if heartbeats_path.exists():
    for line in heartbeats_path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s:
            continue
        try:
            row = json.loads(s)
        except Exception:
            continue
        if str(row.get("step")) != step:
            continue
        role = (row.get("role") or "").strip()
        ts = (row.get("timestamp") or "").strip()
        if not role or not ts:
            continue
        prev = latest_hb_by_role.get(role)
        if prev is None or ts > prev:
            latest_hb_by_role[role] = ts

step_obj = state.get("steps", {}).get(step, {})
primary = (step_obj.get("agent") or "").strip()
supports = [s.strip() for s in (step_obj.get("support_agents") or []) if s and s.strip()]
roles = []
for role in [primary] + supports:
    if role and role not in roles:
        roles.append(role)

def role_status(role: str):
    key = f"step:{step}:role:{role}:mode:headless"
    entry = idem.get(key, {})
    report_path = reports_dir / f"{role}-report.md"
    has_report = report_path.exists()
    pid = entry.get("pid")
    launched = entry.get("status") == "launched"
    completed = entry.get("status") == "completed"

    log_path = Path(entry.get("log_path", str(logs_dir / f"{role}.log")))
    log_age = None
    if log_path.exists():
        log_age = int(now_ts - log_path.stat().st_mtime)
    hb_age = None
    hb_ts = latest_hb_by_role.get(role)
    if hb_ts:
        try:
            hb_epoch = calendar.timegm(time.strptime(hb_ts, "%Y-%m-%dT%H:%M:%SZ"))
            hb_age = int(now_ts - hb_epoch)
        except Exception:
            hb_age = None
    activity_age = hb_age if hb_age is not None else log_age

    running = False
    if isinstance(pid, int) and pid > 0:
        try:
            os.kill(pid, 0)
            running = True
        except OSError:
            running = False

    if has_report or completed:
        status = "done"
    elif launched and running:
        status = "stale" if (activity_age is not None and activity_age > stale_seconds) else "running"
    elif launched and not running:
        status = "blocked"
    else:
        status = "pending"

    chat_id = ((sessions.get("roles", {}) or {}).get(role, {}) or {}).get("chat_id", "")
    return {
        "role": role,
        "status": status,
        "pid": pid if isinstance(pid, int) else "-",
        "chat_id": chat_id,
        "log_age": "-" if log_age is None else f"{log_age}s",
        "hb_age": "-" if hb_age is None else f"{hb_age}s",
        "report": "yes" if has_report else "no",
    }

rows = [role_status(r) for r in roles]
counts = {"running": 0, "stale": 0, "blocked": 0, "done": 0, "pending": 0}
for row in rows:
    counts[row["status"]] = counts.get(row["status"], 0) + 1

print(f"Step {step}: {step_obj.get('name','')}")
print(f"Dispatch dir: {dispatch_dir.relative_to(repo_root)}")
print(
    f"Summary: running={counts['running']} stale={counts['stale']} "
    f"blocked={counts['blocked']} done={counts['done']} pending={counts['pending']}"
)
print("")
for row in rows:
    chat = row["chat_id"][:12] + "..." if row["chat_id"] and len(row["chat_id"]) > 15 else (row["chat_id"] or "-")
    print(
        f"- @{row['role']}: {row['status']:<7} "
        f"pid={row['pid']} report={row['report']} log_age={row['log_age']} hb_age={row['hb_age']} chat={chat}"
    )
print("")
PY
      ;;
    run)
      echo -e "\n${BLUE}${BOLD}[TEAM] PM run loop (single cycle)${NC}"
      echo -e "Current step: ${BOLD}$step — $step_name${NC}"
      echo -e "Spawn roles: ${YELLOW}${role_list}${NC}"
      if [[ "$step_status" == "pending" ]]; then
        echo -e "Step đang pending, auto start step trước khi delegate..."
        cmd_start
      fi
      cmd_dispatch --headless "$@"
      echo -e "${YELLOW}Workers đang chạy nền. Sau khi đủ thời gian xử lý, chạy:${NC}"
      echo -e "  ${BOLD}bash scripts/workflow.sh team sync${NC}\n"
      ;;
    *)
      echo -e "${RED}Unknown team action: $action${NC}"
      echo -e "Usage: bash scripts/workflow.sh team <start|delegate|sync|status|monitor|run>\n"
      exit 1
      ;;
  esac
}

cmd_brainstorm() {
  local project_name=""
  local auto_sync="false"
  local wait_seconds="30"
  local topic_parts=()
  local delegate_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        project_name="${2:-}"
        shift 2
        ;;
      --sync)
        auto_sync="true"
        shift
        ;;
      --wait)
        wait_seconds="${2:-30}"
        shift 2
        ;;
      --launch|--headless|--trust|--dry-run|--force-run)
        delegate_args+=("$1")
        shift
        ;;
      *)
        topic_parts+=("$1")
        shift
        ;;
    esac
  done

  local topic="${topic_parts[*]}"
  local step
  step=$(wf_json_get "current_step")

  if [[ -z "$step" || "$step" == "0" ]]; then
    local effective_project="$project_name"
    [[ -z "$effective_project" ]] && effective_project="Auto Brainstorm Project"
    echo -e "${CYAN}Workflow chưa init, tự khởi tạo project: ${BOLD}${effective_project}${NC}"
    cmd_init --project "$effective_project"
    step=$(wf_json_get "current_step")
  fi

  if [[ -n "$topic" ]]; then
    echo -e "${CYAN}Brainstorm topic:${NC} $topic"
  fi

  if [[ ${#delegate_args[@]} -gt 0 ]]; then
    cmd_team delegate "${delegate_args[@]}"
  else
    cmd_team delegate
  fi

  if [[ "$auto_sync" == "true" ]]; then
    if [[ "$wait_seconds" =~ ^[0-9]+$ ]] && [[ "$wait_seconds" -gt 0 ]]; then
      echo -e "${YELLOW}Đợi ${wait_seconds}s trước khi sync...${NC}"
      sleep "$wait_seconds"
    fi
    cmd_team sync
  fi
}
