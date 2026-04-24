---
description: PM collect — thu thập tất cả worker reports, tổng hợp, và chuẩn bị approval decision
---

Bạn là PM Agent. Tất cả worker agents đã hoàn thành. Hãy thu thập và tổng hợp kết quả.

## Thực hiện theo thứ tự:

**Bước 1 — Thu thập reports:**
```bash
flowctl collect
```

**Bước 2 — Đọc từng report:**

Đọc tất cả files trong `workflows/dispatch/step-[N]/reports/`:
```
@workflows/dispatch/step-[N]/reports/[role]-report.md
```

**Bước 3 — Tổng hợp và trình bày với user:**

Tạo summary theo format sau:

```markdown
## 📋 STEP [N] — COLLECT SUMMARY

### Agents đã báo cáo: [N/N]
- ✅ @[role1] — [một câu tóm tắt]
- ✅ @[role2] — [một câu tóm tắt]
- ⚠️ @[role3] — BLOCKED: [mô tả]

### Deliverables tổng hợp
- [file1] — [role tạo] — [mô tả]
- [file2] — [role tạo] — [mô tả]

### Decisions đã đưa ra
- [decision 1]
- [decision 2]

### Blockers cần PM xử lý
- [blocker nếu có]

### Rủi ro cần biết
- [risk nếu có]
```

**Bước 4 — Chạy QA gate check:**
```bash
flowctl gate-check
```

**Bước 5 — Trình bày approval recommendation:**

Dựa trên summary và gate check, đưa ra recommendation:

```markdown
## 🔔 APPROVAL RECOMMENDATION — Step [N]: [Name]

**PM Recommendation**: APPROVE / REJECT / CONDITIONAL

**Lý do**: [2-3 câu]

**Nếu APPROVE**: Gõ `flowctl approve --by "PM"`
**Nếu CONDITIONAL**: [liệt kê items cần fix trong 48h]
**Nếu REJECT**: [lý do cụ thể]
```

**User quyết định cuối cùng.** PM không tự approve.

## Lưu ý:
- Nếu có report bị thiếu → `flowctl team recover --role <role> --mode retry`
- Nếu gate check fail → không recommend approve cho đến khi fix
- Ghi lại tất cả quyết định quan trọng: `flowctl decision "nội dung"`
