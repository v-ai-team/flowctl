# IT Product Team Workflow — Orchestration Guide
# Đọc file này trước khi làm bất cứ việc gì trong project

## ⚡ Khởi Động Nhanh

Khi bắt đầu một session mới, dùng **MCP tools** (không phải bash — tiết kiệm ~95% token):

```
# 1. Đọc workflow state
wf_state()              ← thay cho: cat workflow-state.json + bash scripts/workflow.sh status

# 2. Đọc context đầy đủ của step hiện tại
wf_step_context()       ← thay cho: đọc 5+ files riêng lẻ

# 3. Load graph context (nếu Graphify available)
graphify_query("project:requirements")
```

> **Quy tắc token**: Dùng MCP tools trước bash. Bash chỉ dùng cho write operations.

---

## 🤖 Hệ Thống Agent

### Nguyên Tắc Kích Hoạt Agent

**Chỉ kích hoạt agent phù hợp với step hiện tại.** Đọc `workflow-state.json` để biết step nào đang active, sau đó dùng agent tương ứng.

| Step | Agent Chính | Agent Hỗ Trợ | File Agent |
|------|-------------|--------------|------------|
| 1 — Requirements | `@pm` | `@tech-lead` | `.cursor/agents/pm-agent.md` |
| 2 — System Design | `@tech-lead` | `@backend`, `@pm` | `.cursor/agents/tech-lead-agent.md` |
| 3 — UI/UX Design | `@ui-ux` | `@frontend`, `@pm` | `.cursor/agents/ui-ux-agent.md` |
| 4 — Backend Dev | `@backend` | `@tech-lead` | `.cursor/agents/backend-dev-agent.md` |
| 5 — Frontend Dev | `@frontend` | `@ui-ux`, `@tech-lead` | `.cursor/agents/frontend-dev-agent.md` |
| 6 — Integration | `@tech-lead` | `@backend`, `@frontend` | `.cursor/agents/tech-lead-agent.md` |
| 7 — QA Testing | `@qa` | tất cả devs | `.cursor/agents/qa-agent.md` |
| 8 — DevOps | `@devops` | `@tech-lead` | `.cursor/agents/devops-agent.md` |
| 9 — Release | `@pm` + `@tech-lead` | tất cả | tất cả agents |

### Parallel Agent Execution

Để chạy nhiều agents song song (phân tích đồng thời):

```
# Ví dụ: Step 1 — PM và Tech Lead phân tích song song
Mở 2 Cursor Agent Tabs:
  Tab 1: @pm — Thu thập và phân tích requirements
  Tab 2: @tech-lead — Đánh giá feasibility kỹ thuật
→ Tổng hợp kết quả về main tab → Approval gate
```

---

## 🔧 MCP Tools Có Sẵn

### ⚡ Shell Proxy Tools — DÙNG TRƯỚC (token-efficient)

Thay thế bash read operations. Cache tự động, structured JSON output.

```
wf_state()                      — Workflow state (step, status, blockers, decisions)
                                  Thay: cat workflow-state.json + bash scripts/workflow.sh status
                                  Saving: ~1,900 → ~100 tokens (95%)

wf_git(commits?)                — Git snapshot (branch, commits, changed files)
                                  Thay: git log + git status + git diff --stat
                                  Saving: ~1,000 → ~80 tokens (92%)

wf_step_context(step?)          — Full step context (state + decisions + blockers + war room)
                                  Thay: đọc 5+ files riêng lẻ
                                  Saving: ~5,000 → ~300 tokens (94%)

wf_files(dir?, pattern?, depth?) — Project file listing
                                  Thay: ls -la + find commands
                                  Saving: ~500 → ~100 tokens (80%)

wf_read(path, max_lines?, compress?) — Read file with caching
                                  Thay: cat <file> (cache hit = free)
                                  Saving: varies, cache hit = ~50 tokens

wf_env()                        — OS, tool versions, paths (cached forever)
                                  Thay: which + --version commands
                                  Saving: ~300 → ~50 tokens (83%)

wf_cache_invalidate(scope?)     — Invalidate cache (all|git|state|files)
                                  Gọi sau khi write/modify state
```

**Cache tự động invalidate:**
- Sau mỗi git commit → git cache reset (post-commit hook)
- Sau mỗi workflow action → state cache reset (SessionStart hook)

**Thứ tự ưu tiên khi cần thông tin:**
```
1. wf_step_context()  ← tất cả trong 1 call
2. wf_state()         ← nếu chỉ cần workflow state
3. graphify_query()   ← nếu cần knowledge graph
4. wf_git()           ← nếu cần git context
5. wf_read()          ← nếu cần đọc file cụ thể
6. bash [cmd]         ← CHỈ cho write operations
```

---

### Graphify Tools (knowledge graph)

```
graphify_query(topic)           — Query knowledge graph theo chủ đề
graphify_search(keyword)        — Tìm nodes liên quan đến keyword
graphify_get_dependencies(node) — Lấy dependencies của một component
graphify_get_clusters()         — Xem các cluster code liên quan
graphify_update_node(id, data)  — Cập nhật node trong graph
graphify_snapshot(label)        — Tạo snapshot của graph tại thời điểm hiện tại
```

**Khi nào dùng:**
- Bắt đầu mỗi step: query context từ các steps trước
- Sau mỗi quyết định quan trọng: update node
- Cuối mỗi step: tạo snapshot

### GitNexus Tools (code intelligence)

```
gitnexus_query(question)        — Hỏi về cấu trúc codebase
gitnexus_get_context(file)      — Lấy context đầy đủ của một file
gitnexus_detect_changes()       — Phát hiện thay đổi kể từ last commit
gitnexus_impact_analysis(file)  — Phân tích impact khi thay đổi file
gitnexus_find_related(symbol)   — Tìm code liên quan đến symbol
gitnexus_get_architecture()     — Tổng quan kiến trúc codebase
```

**Khi nào dùng:**
- Trước khi code: query architecture
- Trước khi thay đổi: impact analysis
- Sau khi code: detect_changes để verify scope

### Workflow State Tools

```
workflow_get_state()            — Đọc trạng thái hiện tại
workflow_advance_step(notes)    — Chuyển sang step tiếp theo (cần approval)
workflow_request_approval(data) — Gửi yêu cầu approval
workflow_add_blocker(desc)      — Ghi nhận blocker
workflow_resolve_blocker(id)    — Đánh dấu blocker đã resolve
workflow_add_decision(data)     — Ghi lại quyết định quan trọng
```

---

## 📋 Quy Trình Mỗi Step

### Khi BẮT ĐẦU một step mới:

```
1. workflow_get_state()                    → Xác nhận step và agent
2. graphify_query("step:<N>:context")      → Load context từ steps trước
3. gitnexus_get_architecture()             → Hiểu codebase hiện tại
4. Đọc .cursor/agents/<role>-agent.md      → Load agent persona và skills
5. Tạo kickoff document                    → workflows/steps/NN-<name>.md
```

### Trong khi THỰC HIỆN step:

```
- Mọi quyết định quan trọng → workflow_add_decision()
- Mọi blocker phát sinh     → workflow_add_blocker()
- Thay đổi code đáng kể     → gitnexus_detect_changes() để verify
- Milestone quan trọng      → graphify_update_node()
```

### Khi KẾT THÚC step:

```
1. Tạo step summary (dùng workflows/templates/step-summary-template.md)
2. graphify_snapshot("step-<N>-complete")
3. Điền review checklist (workflows/templates/review-checklist-template.md)
4. workflow_request_approval({step, summary, checklist})
5. ⏸️  DỪNG — Chờ human approve trước khi sang step tiếp theo
```

### Khi NHẬN APPROVAL:

```
APPROVED       → workflow_advance_step() → Bắt đầu step N+1
REJECTED       → Address concerns → Re-submit approval request
CONDITIONAL    → Fix specific items trong 48h → Verify → Continue
```

---

## 🚨 Approval Gate — Quy Tắc Bắt Buộc

> **QUAN TRỌNG**: Agent KHÔNG ĐƯỢC tự động chuyển sang step tiếp theo.
> Mỗi step kết thúc bằng một approval request. Agent phải DỪNG và chờ
> human approve (hoặc reject) trước khi tiếp tục.

**Format Approval Request:**

```markdown
## 🔔 APPROVAL REQUEST — Step [N]: [Step Name]

**Agent**: @[role]
**Ngày hoàn thành**: YYYY-MM-DD
**Duration**: X ngày

### Tóm Tắt (Executive Summary)
[2-3 câu cho PM đọc, không kỹ thuật]

### Deliverables Hoàn Thành
- [x] Deliverable 1
- [x] Deliverable 2

### Metrics
- Coverage: X%
- Tests passed: N/N
- Performance: [kết quả]

### Risks & Issues
[Liệt kê nếu có]

### Graphify Snapshot
`step-[N]-complete` — [số nodes, relationships]

---
**Quyết định cần thiết**: APPROVE / REJECT / CONDITIONAL
**Người approve**: @pm và @tech-lead
```

---

## 🔄 Parallel Execution Patterns

### Pattern 1: Parallel Research (Steps 1-2)

```
Main Agent (Orchestrator)
    ├── [Tab 1] @pm         → Stakeholder requirements analysis
    ├── [Tab 2] @tech-lead  → Technical feasibility + constraints
    └── [Tab 3] @ui-ux      → Competitor UX research
    ↓
Merge results → Consolidated PRD → Approval Gate
```

### Pattern 2: Parallel Development (Steps 4-5)

```
Điều kiện: API contract đã được define ở Step 2

Main Agent
    ├── [Tab 1] @backend   → API implementation
    └── [Tab 2] @frontend  → UI implementation với mock API
    ↓
Integration checkpoint mỗi ngày → Final merge → Step 6
```

### Pattern 3: Parallel QA (Step 7)

```
Main Agent
    ├── [Tab 1] @qa        → Manual test cases
    ├── [Tab 2] @backend   → Unit + integration tests
    └── [Tab 3] @frontend  → E2E tests + visual regression
    ↓
Tổng hợp test results → QA sign-off → Approval Gate
```

---

## 📁 Cấu Trúc File Quan Trọng

```
CLAUDE.md                          ← File này — đọc đầu tiên
workflow-state.json                ← Trạng thái hiện tại của workflow
setup.sh                           ← Cài đặt Graphify + GitNexus
scripts/workflow.sh                ← CLI quản lý workflow

.cursor/
  mcp.json                         ← MCP server config (Graphify + GitNexus)
  agents/
    pm-agent.md                    ← PM Agent persona + skills
    tech-lead-agent.md             ← Tech Lead Agent
    backend-dev-agent.md           ← Backend Dev Agent
    frontend-dev-agent.md          ← Frontend Dev Agent
    ui-ux-agent.md                 ← UI/UX Agent
    devops-agent.md                ← DevOps Agent
    qa-agent.md                    ← QA Agent
  rules/
    global-rules.md                ← Quy tắc cho tất cả agents
    workflow-rules.md              ← Quy tắc workflow

workflows/
  steps/                           ← Step documents (tạo khi làm)
  templates/
    step-summary-template.md       ← Template tạo summary
    review-checklist-template.md   ← Template review
    approval-request-template.md   ← Template approval

.graphify/
  graph.json                       ← Knowledge graph data

.claude/
  mcp-workflow-state.js            ← Workflow state MCP server
  settings.json                    ← Claude Code permissions
```

---

## 🛠️ Setup Lần Đầu

```bash
# Bước 1: Cài đặt tools
bash setup.sh

# Bước 2: Khởi tạo workflow
bash scripts/workflow.sh init --project "Tên dự án"

# Bước 3: Reload Cursor
# Cmd/Ctrl+Shift+P → "Developer: Reload Window"

# Bước 4: Verify MCP servers
# Cursor → Settings → Features → MCP → Kiểm tra 3 servers màu xanh
```
