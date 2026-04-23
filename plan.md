# Workflow Orchestration Improvement Plan

Updated: 2026-04-23
Owner: PM Gateway (`workflow-conduct`)

## Goal

Build a step-based agent orchestration flow where:
- PM is the only user-facing gateway
- agents spawn by role per step
- approvals are evidence-driven via QA gates
- progress can be monitored with clear operational signals

## Progress Snapshot

- Current maturity score: **7.8/10**
- Target maturity score: **10/10**
- Current phase: **P1 observability kickoff**

## Checklist

### P0 — Must-Have Safety Controls

- [x] Add one-command workflow entrypoint in `scripts/workflow.sh` (`brainstorm`)
- [x] Add slash command scaffolding for `/workflow-conduct`
- [x] Enforce step-based role delegation (`team delegate`)
- [x] Remove forced `--trust` in delegate path to avoid permission failures
- [x] Add QA gate policy file: `workflows/gates/qa-gate.v1.json`
- [x] Add explicit gate check command: `bash scripts/workflow.sh gate-check`
- [x] Block `approve` when gate fails (default fail-closed)
- [x] Keep controlled bypass: `approve --skip-gate --by "..."`
- [x] Fix argument parsing bugs in:
  - `blocker add`
  - `blocker resolve`
  - `decision`
- [x] Add gate report artifact per step (pass/fail log with timestamp)
- [x] Add idempotency key for `(runId, step, role)` to prevent duplicate side effects
- [x] Add state lock/lease to prevent race conditions across concurrent runs

### P1 — Observability & Recovery

- [x] Add role session registry file (e.g. `workflows/runtime/role-sessions.json`)
- [x] Persist `role -> chatId` and implement `create-chat` + `resume` strategy
- [x] Add `team monitor` for near-realtime progress (status, stale, blocked, done)
- [x] Parse `stream-json` events into normalized heartbeat records
- [x] Add correlation ID (`workflowId/runId/step/role`) across logs and reports
- [x] Add timeout + retry policy classes (transient vs permanent vs policy)
- [x] Add failure recovery runbook (resume, retry, rollback rules)

### P2 — Production-Grade Governance

- [x] Add policy-as-code for trust/tool permission per role
- [x] Add budget guardrails (token/time caps + circuit breaker)
  - Define budget policy spec in `workflows/policies/budget-policy.v1.json`
  - Enforce per-run caps: `max_tokens_total`, `max_runtime_seconds`, `max_cost_usd`
  - Enforce per-role caps: `max_tokens_per_role`, `max_runtime_per_role_seconds`
  - Add soft-threshold alerts at 70% and 90% budget utilization
  - Add hard-stop circuit breaker on cap breach with fail-closed step state
  - Emit budget events into runtime artifacts for audit (`budget-events.jsonl`)
  - Require explicit PM override reason for one-time budget exception
- [ ] Add immutable evidence integrity checks (checksum/signature)
- [ ] Add full traceability map:
  - requirement -> task -> runId -> evidence -> approval decision
- [ ] Add chaos test suite for orchestration reliability
- [ ] Add release dashboard summary for PM approvals

## Operational Commands

### Core

- Start or continue orchestration:
  - `bash scripts/workflow.sh brainstorm "<topic>"`
- Delegate current step roles:
  - `bash scripts/workflow.sh team delegate`
- Collect worker reports:
  - `bash scripts/workflow.sh collect`
- Monitor role runtime state:
  - `bash scripts/workflow.sh team monitor --stale-seconds 300`
- Recover failed role safely:
  - `bash scripts/workflow.sh team recover --role <role> --mode resume|retry|rollback --dry-run`
- Check gate:
  - `bash scripts/workflow.sh gate-check`
- Approve step (when gate passes):
  - `bash scripts/workflow.sh approve --by "Your Name"`

### Safety

- Dry run delegate:
  - `bash scripts/workflow.sh team delegate --dry-run`
- Controlled bypass (exception only):
  - `bash scripts/workflow.sh approve --skip-gate --by "Your Name"`
- Run TDD regression suite before major refactor:
  - `bash scripts/test-workflow-tdd-regression.sh`
- Update role policy guardrails:
  - `workflows/policies/role-policy.v1.json`

## Definition of Done for 10/10

- [ ] No false approvals (all approvals backed by gate + evidence)
- [ ] Idempotent retries for all role-step executions
- [ ] Deterministic resume behavior for persistent role sessions
- [ ] Observable runtime with actionable alerts for stalls/failures
- [ ] Security guardrails for trust and tool permissions
- [ ] Automated regression + chaos checks integrated in release flow

## Next Action (Immediate)

- [x] Implement role session persistence (`role-sessions.json`) with resume support
- [x] Add `team monitor` heartbeat view (running/blocked/stale/done)
- [x] Parse stream-json runtime events into `workflows/runtime/heartbeats.jsonl`
- [x] Add correlation ID metadata (`workflowId/runId/step/role`) to heartbeats/idempotency and monitor output
- [x] Add timeout/retry policy metadata + monitor classification (`transient`/`permanent`/`policy`)
- [x] Add recovery runbook and `team recover` command flow (`resume`/`retry`/`rollback`)
- [x] Add TDD regression suite to protect legacy business logic (`scripts/test-workflow-tdd-regression.sh`)
- [x] Expand TDD regression coverage for lock conflict, collect idempotency, reset flow, skip-gate audit, and CLI validation
- [ ] Add budget policy artifact `workflows/policies/budget-policy.v1.json` with per-run and per-role caps
- [ ] Add budget meter module in `scripts/workflow/lib/*` to track token/time/cost spend by correlation ID
- [ ] Add circuit breaker state transitions (`open`/`half-open`/`closed`) with cooldown + manual reset path
- [ ] Add `team monitor` budget view for PM heartbeat (`% used`, `eta to cap`, `breaker state`)
- [ ] Add regression tests for budget cutoff, exception audit, and breaker recovery behavior
- [x] Split Phase 1: extract shared modules (`common/state/lock/gate`) into `scripts/workflow/lib/*` with behavior preserved
- [x] Split Phase 2: extract `cmd_dispatch` and `cmd_collect` into `scripts/workflow/lib/dispatch.sh`
- [x] Split Phase 3: extract orchestration commands (`cmd_team`, `cmd_brainstorm`) into `scripts/workflow/lib/orchestration.sh`
- [x] Split Phase 4: extract reporting/reset commands (`cmd_summary`, `cmd_history`, `cmd_reset`) into `scripts/workflow/lib/reporting.sh`
- [x] Split Phase 5: centralize runtime config in `scripts/workflow/lib/config.sh` and add module architecture docs in `scripts/workflow/lib/README.md`
- [x] Split Phase 5.1: normalize shared helper naming with `wf_*` prefix across modules and entrypoint call sites
- [x] Split Phase 5.2: add backward-compatible helper aliases (legacy -> `wf_*`) with deprecation warnings for migration safety
