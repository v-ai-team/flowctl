#!/usr/bin/env bash

# Centralized runtime/config paths for workflow engine.
# WORKFLOW_ROOT can be injected by caller; fallback keeps module usable standalone.
: "${WORKFLOW_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

REPO_ROOT="$WORKFLOW_ROOT"
STATE_FILE="$REPO_ROOT/workflow-state.json"
QA_GATE_FILE="$REPO_ROOT/workflows/gates/qa-gate.v1.json"
WORKFLOW_LOCK_DIR="$REPO_ROOT/.workflow-lock"
IDEMPOTENCY_FILE="$REPO_ROOT/workflows/runtime/idempotency.json"
ROLE_SESSIONS_FILE="$REPO_ROOT/workflows/runtime/role-sessions.json"
HEARTBEATS_FILE="$REPO_ROOT/workflows/runtime/heartbeats.jsonl"
ROLE_POLICY_FILE="$REPO_ROOT/workflows/policies/role-policy.v1.json"
BUDGET_POLICY_FILE="$REPO_ROOT/workflows/policies/budget-policy.v1.json"
BUDGET_STATE_FILE="$REPO_ROOT/workflows/runtime/budget-state.json"
BUDGET_EVENTS_FILE="$REPO_ROOT/workflows/runtime/budget-events.jsonl"
EVIDENCE_DIR="$REPO_ROOT/workflows/runtime/evidence"
TRACEABILITY_FILE="$REPO_ROOT/workflows/runtime/traceability-map.jsonl"
RELEASE_DASHBOARD_DIR="$REPO_ROOT/workflows/runtime/release-dashboard"

# Module directory for dynamic source in entrypoint.
LIB_DIR="$REPO_ROOT/scripts/workflow/lib"
