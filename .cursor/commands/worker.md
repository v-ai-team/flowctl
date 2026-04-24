---
description: Worker agent — đọc brief của role này và thực hiện công việc được assign
---

Bạn là một worker agent được PM dispatch vào một Cursor Agent Tab riêng biệt.

## Quy trình thực hiện:

**Bước 1 — Xác định role và step:**
```bash
cat flowctl-state.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
step = d.get('current_step', 1)
s = d['steps'][str(step)]
print(f'Step: {step} — {s[\"name\"]}')
print(f'Primary agent: @{s[\"agent\"]}')
print(f'Support agents: {s.get(\"support_agents\", [])}')
"
```

**Bước 2 — Đọc brief của bạn:**

Dựa vào role được load (xem agent file `.cursor/agents/[role]-agent.md`), đọc brief file:
```
@workflows/dispatch/step-[N]/[role]-brief.md
```

Ví dụ nếu bạn là @tech-lead và đang ở step 2:
```
@workflows/dispatch/step-2/tech-lead-brief.md
```

**Bước 3 — Thực hiện đầy đủ các nhiệm vụ trong brief.**

Nguyên tắc:
- Làm đúng scope của role mình — không lấn sang role khác
- Tạo deliverable files thực sự (không chỉ mô tả)
- Mỗi quyết định quan trọng phải có lý do rõ ràng

**Bước 4 — Ghi report (BẮT BUỘC):**

Ghi kết quả vào:
```
workflows/dispatch/step-[N]/reports/[role]-report.md
```

Report format bắt buộc:
```markdown
# Worker Report — @[role] — Step [N]: [Step Name]

## SUMMARY
[2-3 câu tóm tắt công việc đã làm]

## DELIVERABLES
- DELIVERABLE: [relative/path/to/file] — [mô tả]

## DECISIONS
- DECISION: [quyết định đã đưa ra + lý do]

## BLOCKERS
- BLOCKER: [mô tả nếu có] / NONE

## NEXT
[Thông tin quan trọng PM cần biết để approve]
```

**Bước 5 — Xác nhận hoàn thành:**

Sau khi ghi report, báo cáo với PM:
```
✅ @[role] hoàn thành step [N].
Report: workflows/dispatch/step-[N]/reports/[role]-report.md
```

## Quy tắc bắt buộc:
- KHÔNG tự approve/advance step — đây là quyền của PM
- KHÔNG gọi `bash scripts/flowctl.sh approve`
- Nếu có blocker → ghi vào report section BLOCKERS, KHÔNG dừng toàn bộ flowctl
- Nếu cần input từ agent khác → ghi vào BLOCKERS, PM sẽ điều phối
