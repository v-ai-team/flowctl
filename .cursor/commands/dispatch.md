---
description: PM dispatch — tạo briefs và Spawn Board cho tất cả agents trong step hiện tại
---

Bạn là PM Agent đang điều phối step hiện tại của workflow.

## Thực hiện theo thứ tự sau:

**Bước 1 — Đọc trạng thái workflow:**
```bash
bash scripts/workflow.sh status
```

**Bước 2 — Generate briefs + Spawn Board:**
```bash
bash scripts/workflow.sh cursor-dispatch
```

**Bước 3 — Trình bày Spawn Board cho user.**

Sau khi có output từ Bước 2, giải thích rõ cho user:

1. **MODE A (Cursor Agent Tabs)** — Khuyến nghị khi muốn thấy từng agent làm việc:
   - Mở Agents Window: `Cmd+Shift+I` (Mac) hoặc `Ctrl+Shift+I` (Win)
   - Tạo new tab cho mỗi role được liệt kê
   - Paste đúng prompt được generate cho mỗi tab
   - Mỗi tab tự đọc brief và tự thực hiện

2. **MODE B (Task Tool, inline)** — Khuyến nghị khi muốn tự động:
   - Dùng Cursor Task tool để spawn subagents trực tiếp từ cửa sổ này
   - Subagents chạy parallel, kết quả trả về trong cùng thread này

**Bước 4 — Hướng dẫn collect:**

Sau khi tất cả agents hoàn thành, PM chạy:
```bash
bash scripts/workflow.sh collect
```
hoặc gõ `/collect` trong cửa sổ PM này.

## Lưu ý:
- Đừng approve step cho đến khi `/collect` cho thấy tất cả reports đã có
- Nếu một agent bị stale > 5 phút, chạy: `bash scripts/workflow.sh team recover --role <role> --mode resume`
- PM là người duy nhất có quyền approve/reject step
