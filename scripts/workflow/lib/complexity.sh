#!/usr/bin/env bash
# complexity.sh — Auto-score step complexity để quyết định có cần War Room không
# Score 1-5:  1-2 = simple (skip War Room), 3-5 = complex (trigger War Room)

# Returns: integer 1-5
wf_complexity_score() {
  local step="${1:-}"
  [[ -z "$step" ]] && step=$(wf_json_get "current_step")

  python3 - <<PY
import json
from pathlib import Path

state_path = Path("$STATE_FILE")
data = json.loads(state_path.read_text(encoding="utf-8"))
step = str($step)
s = data["steps"].get(step, {})

score = 1

# Rule 1: number of roles involved
primary = s.get("agent", "")
supports = [a for a in s.get("support_agents", []) if a and a != primary]
n_roles = 1 + len(supports)
if n_roles >= 4:
    score += 2
elif n_roles >= 3:
    score += 1

# Rule 2: step type (code steps are inherently complex)
code_steps = {"4", "5", "6"}
complex_steps = {"2", "7", "8"}
if step in code_steps:
    score += 2
elif step in complex_steps:
    score += 1

# Rule 3: open blockers from prior steps (carry-over complexity)
open_blockers = 0
for sn, sobj in data["steps"].items():
    if int(sn) < int(step):
        for b in sobj.get("blockers", []):
            if not b.get("resolved"):
                open_blockers += 1
if open_blockers > 0:
    score += 1

# Clamp to 1-5
score = max(1, min(5, score))
print(score)
PY
}

cmd_complexity() {
  local step
  step=$(wf_require_initialized_workflow)
  local score
  score=$(wf_complexity_score "$step")

  local label verdict color
  if [[ "$score" -le 2 ]]; then
    label="LOW"; verdict="Skip War Room → dispatch trực tiếp"; color="$GREEN"
  elif [[ "$score" -eq 3 ]]; then
    label="MEDIUM"; verdict="War Room recommended"; color="$YELLOW"
  else
    label="HIGH"; verdict="War Room required"; color="$RED"
  fi

  echo -e "\n${BOLD}Complexity Score — Step $step${NC}"
  echo -e "  Score : ${color}${BOLD}$score / 5${NC} ($label)"
  echo -e "  Action: $verdict\n"
}
