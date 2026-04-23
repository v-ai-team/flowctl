# workflow-conduct

## Mục tiêu
Khi user gọi `/workflow-conduct <topic>`, tự động orchestration theo step hiện tại bằng workflow engine, không yêu cầu user chạy lệnh thủ công.

## Trigger
- User gọi: `/workflow-conduct ...`
- Hoặc yêu cầu tương đương: "chạy tự động theo step hiện tại"

## Hành vi bắt buộc
1. Parse topic từ input user.
2. Nếu không phải dry-run, chạy flow tự động:
   - `bash scripts/workflow.sh brainstorm --headless "<topic>"`
   - Poll `bash scripts/workflow.sh team monitor --stale-seconds 300` mỗi 20-30 giây (tối đa 10 phút)
   - Khi workers kết thúc ổn định: `bash scripts/workflow.sh team sync`
   - Sau sync, luôn chạy:
     - `bash scripts/workflow.sh release-dashboard --no-write`
     - `bash scripts/workflow.sh gate-check`
3. Tôn trọng trạng thái `workflow-state.json`:
   - Nếu chưa init (`current_step = 0`) thì auto init bằng project mặc định hoặc tên user truyền vào.
   - Chỉ delegate đúng agent của step hiện tại.
4. Logic tự hồi phục khi chạy tự động:
   - Nếu breaker `open`/`half-open` → `bash scripts/workflow.sh team budget-reset --reason "manual recovery from workflow-conduct"`
   - Nếu role `blocked` và còn retry budget → `bash scripts/workflow.sh team recover --role <role> --mode retry`
   - Nếu role `stale` → `bash scripts/workflow.sh team recover --role <role> --mode resume`
5. Sau khi dispatch/sync, báo cáo lại:
   - Step hiện tại
   - Roles đã spawn
   - Đường dẫn reports/logs
   - Gợi ý bước kế tiếp (`team sync`, `release-dashboard`, `gate-check`, `approve`)
6. Trước khi đề xuất approve, ưu tiên nhắc user chạy:
   - `bash scripts/workflow.sh release-dashboard`
   - `bash scripts/workflow.sh gate-check`
7. Nếu phát hiện budget breaker đang `open` hoặc `half-open`, nhắc đường recovery:
   - `bash scripts/workflow.sh team budget-reset --reason "manual recovery"`

## Tuỳ chọn mở rộng
- Chạy kèm sync tự động:
  - `bash scripts/workflow.sh brainstorm --sync --wait 30 "<topic>"`
- Kiểm tra trước bằng dry-run:
  - `bash scripts/workflow.sh brainstorm --dry-run "<topic>"`

## Guardrails
- Không tự động approve step (trừ khi user yêu cầu rõ ràng).
- Không bỏ qua approval gate.
- Không spawn agent ngoài scope step hiện tại.
- Không gợi ý approve khi `release-dashboard` báo `approval_ready: no`.
