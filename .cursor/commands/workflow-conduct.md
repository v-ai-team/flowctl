---
description: PM điều phối workflow step hoàn toàn tự động qua Task tool — user chỉ cần approve kết quả
---

Bạn là PM Agent. Thực hiện toàn bộ workflow step **tự động** không cần user làm gì ngoài approve.

Topic/context: $ARGUMENTS

---

## Luồng tự động (PM tự làm hết):

### 1 — Đọc state
```bash
bash scripts/workflow.sh status
```
Nếu step chưa start → `bash scripts/workflow.sh start`.

### 2 — Tạo briefs
```bash
bash scripts/workflow.sh cursor-dispatch
```
Đọc nội dung brief của từng role từ `workflows/dispatch/step-N/[role]-brief.md`.

### 3 — Spawn sub-agents song song bằng Task tool

Với **mỗi role** trong step hiện tại, spawn subagent:
- `subagent_type`: tên role (vd: `tech-lead`, `backend`, `frontend`)
- `instructions`: toàn bộ nội dung brief file của role đó
- Tất cả spawn **đồng thời** (parallel, is_background: true)

Mỗi subagent phải:
1. Thực hiện nhiệm vụ trong brief
2. Ghi report vào `workflows/dispatch/step-N/reports/[role]-report.md`
3. Trả về "done: [tóm tắt ngắn]"

### 4 — Collect khi tất cả Task tool calls hoàn thành
```bash
bash scripts/workflow.sh collect
```

### 5 — Gate check + Approval recommendation
```bash
bash scripts/workflow.sh gate-check
bash scripts/workflow.sh release-dashboard --no-write
```

Trình bày cho user:
- Tóm tắt từng agent đã làm gì
- Deliverables đã tạo
- Gate check result
- **Recommendation: APPROVE / REJECT / CONDITIONAL**
- **DỪNG — chờ user quyết định. KHÔNG tự approve.**

---

Nếu `--dry-run` trong $ARGUMENTS: chỉ tạo briefs, không spawn.
Nếu `--sync` trong $ARGUMENTS: chỉ collect + summary, không spawn.

---

> **Tại sao dùng Task tool thay vì Agent Tabs?**
> Task tool = 100% tự động, PM spawn parallel subagents không cần user mở window.
> Agent Tabs = user phải mở từng tab thủ công, nhưng thấy được từng agent làm việc real-time.
> Nếu user muốn xem visual → họ có thể mở tabs thủ công song song, nhưng PM không cần chờ.
