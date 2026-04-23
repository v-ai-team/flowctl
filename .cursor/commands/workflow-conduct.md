---
description: Step-based auto delegation via workflow engine
---

Run end-to-end workflow orchestration for the current step using the workflow engine.

User input:
$ARGUMENTS

Execution rules:
1. Treat `$ARGUMENTS` as brainstorm topic.
2. Unless user explicitly asks dry-run, execute autonomous flow in this order:
   - `bash scripts/workflow.sh brainstorm --headless "$ARGUMENTS"`
   - Monitor loop (max 10 minutes): run `bash scripts/workflow.sh team monitor --stale-seconds 300` every 20-30s.
   - If monitor shows all roles are `done` OR no `running/stale` roles remain, run:
     - `bash scripts/workflow.sh team sync`
     - `bash scripts/workflow.sh release-dashboard --no-write`
     - `bash scripts/workflow.sh gate-check`
3. Recovery logic during loop:
   - If breaker is `open`/`half-open`: run `bash scripts/workflow.sh team budget-reset --reason "manual recovery from workflow-conduct"`
   - If a role is `blocked` and retry budget remains: run `bash scripts/workflow.sh team recover --role <role> --mode retry`
   - If a role is `stale`: run `bash scripts/workflow.sh team recover --role <role> --mode resume`
4. If user includes `--dry-run`, `--sync`, `--wait`, or `--project`, pass them through unchanged and skip autonomous loop.
5. After execution, report:
   - Current step and step name
   - Spawned roles
   - Dispatch path and expected reports path
   - Output from `bash scripts/workflow.sh release-dashboard --no-write` (at least `approval_ready`, `gate_passed`, `breaker_state`)
   - Next suggested action (`team sync`, `release-dashboard`, `gate-check`, or `approve`)
   - If breaker is not `closed`, include recovery hint:
     `bash scripts/workflow.sh team budget-reset --reason "manual recovery"`
6. Do not auto-approve any step unless user explicitly says auto-approve.
