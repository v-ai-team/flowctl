#!/usr/bin/env bash

# Centralized runtime/config paths for flowctl engine.
# WORKFLOW_ROOT: nơi chứa flowctl engine/scripts (global package hoặc local repo).
# PROJECT_ROOT: project đang được điều phối flowctl (mặc định current working dir).
: "${WORKFLOW_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
: "${PROJECT_ROOT:=$PWD}"

REPO_ROOT="$PROJECT_ROOT"
STATE_FILE="$REPO_ROOT/flowctl-state.json"
QA_GATE_FILE="$REPO_ROOT/workflows/gates/qa-gate.v1.json"
WORKFLOW_LOCK_DIR="$REPO_ROOT/.flowctl-lock"
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
LIB_DIR="$WORKFLOW_ROOT/scripts/workflow/lib"
