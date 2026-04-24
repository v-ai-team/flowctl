# Architecture — Global Workflow CLI

## Overview
Hệ thống được tổ chức theo mô hình CLI-first, trong đó global command là cổng vào duy nhất cho các thao tác flowctl (`init`, `dispatch`, `collect`, `gate-check`, `approve`, ...).

## High-Level Components
- **Global CLI Entrypoint**
  - Expose command interface thống nhất.
  - Parse options/subcommands và điều phối tới engine scripts.
- **Workflow Engine (existing scripts)**
  - Giữ logic orchestration, gating, reporting, retro.
  - Được gọi thông qua command global thay vì path relative trực tiếp.
- **Project Scaffold Generator**
  - Chịu trách nhiệm bootstrap `.cursor`, `.claude`, `flowctl-state.json`.
  - Hỗ trợ idempotent create + safe defaults.
- **State & Evidence Layer**
  - `flowctl-state.json`: nguồn dữ liệu trạng thái.
  - `workflows/gates/reports/*`, `workflows/runtime/evidence/*`: logs và bằng chứng.

## Command Flow
1. User gọi global CLI command.
2. CLI resolve project root hiện tại.
3. CLI chạy flowctl engine với context project đó.
4. Engine cập nhật state/gates/evidence như quy trình hiện có.

## Compatibility Strategy
- **Phase 1**: hỗ trợ song song global command và script cũ.
- **Phase 2**: docs mặc định dùng global command.
- **Phase 3**: giảm dần phụ thuộc vào gọi script relative trực tiếp.

## Risks and Mitigations
- **Risk**: lệch hành vi giữa global wrapper và script hiện tại.
  - **Mitigation**: giữ wrapper mỏng, chỉ chuyển tham số.
- **Risk**: scaffold ghi đè cấu hình cũ.
  - **Mitigation**: mặc định skip existing files + explicit overwrite flag.
- **Risk**: tài liệu chưa đồng bộ.
  - **Mitigation**: checklist migrate docs và gate kiểm tra command examples.
