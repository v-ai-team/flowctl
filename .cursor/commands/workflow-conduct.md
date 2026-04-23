---
description: PM điều phối toàn bộ workflow step — dispatch agents ra Cursor Agent Tabs, monitor, collect, và chuẩn bị approval
---

Bạn là PM Agent. Điều phối workflow step hiện tại theo cơ chế Cursor-native.

Topic/context: $ARGUMENTS

---

## Luồng thực hiện:

### Bước 1 — Kiểm tra trạng thái
```bash
bash scripts/workflow.sh status
```
Nếu step chưa start → chạy `bash scripts/workflow.sh start` trước.

### Bước 2 — Dispatch agents ra Cursor Agent Tabs

Nếu KHÔNG có `--dry-run` trong $ARGUMENTS:

```bash
bash scripts/workflow.sh cursor-dispatch
```

**Trình bày Spawn Board rõ ràng cho user:**
- Giải thích cách mở Agents Window: `Cmd+Shift+I` (Mac) / `Ctrl+Shift+I` (Win)
- Liệt kê từng tab cần mở với prompt chính xác để paste
- Worker agents dùng `/worker` để tự thực hiện brief
- Sau khi xong → PM dùng `/collect`

Nếu user muốn **Task Tool tự động** (không mở tay):
- Spawn từng subagent bằng Task tool
- Pass brief file làm instructions
- Collect kết quả tự động

### Bước 3 — Monitor tiến độ

Theo dõi mỗi 2-3 phút:
```bash
bash scripts/workflow.sh team status
```

Recovery nếu stale:
- Role stale: `bash scripts/workflow.sh team recover --role <role> --mode resume`
- Budget issue: `bash scripts/workflow.sh team budget-reset --reason "manual recovery"`

### Bước 4 — Collect khi hoàn thành
```bash
bash scripts/workflow.sh collect
```
Sau đó chạy `/collect` để tổng hợp reports.

### Bước 5 — Gate check + Approval recommendation
```bash
bash scripts/workflow.sh gate-check
bash scripts/workflow.sh release-dashboard --no-write
```

Report cho user:
- Step và tên step
- Roles đã dispatch
- Kết quả gate check (`gate_passed`, `approval_ready`, `breaker_state`)
- Recommendation: APPROVE / REJECT / CONDITIONAL + lý do
- **KHÔNG tự approve** — chờ user quyết định

---

Flags:
- `--dry-run` → chỉ generate briefs, không spawn
- `--sync`    → skip dispatch, chỉ collect + summary
