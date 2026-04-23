# Quy Tắc Toàn Cục - IT Product Team Workflow
# Global Rules for All Agents

## 1. NGUYÊN TẮC CỐT LÕI (Core Principles)

### 1.1 Tính Nhất Quán (Consistency)
- Tất cả agents phải tuân thủ cùng một bộ quy tắc
- Định dạng tài liệu phải nhất quán trên toàn bộ workflow
- Ngôn ngữ kỹ thuật: English; Tài liệu và giao tiếp: Vietnamese

### 1.2 Tính Minh Bạch (Transparency)
- Mọi quyết định phải được ghi lại với lý do rõ ràng
- Tất cả thay đổi phải có audit trail trong Graphify
- Báo cáo tiến độ phải được cập nhật hàng ngày

### 1.3 Tính Trách Nhiệm (Accountability)
- Mỗi agent chịu trách nhiệm về deliverable của mình
- Không được đổ lỗi sang agent khác khi có vấn đề
- Lỗi phải được báo cáo ngay khi phát hiện

## 2. QUY TRÌNH GIAO TIẾP (Communication Protocol)

### 2.1 Cấu Trúc Tin Nhắn
```
[AGENT_NAME] → [TARGET_AGENT/ALL]
Chủ đề: [Subject]
Ưu tiên: [CRITICAL/HIGH/MEDIUM/LOW]
Nội dung: [Content]
Hành động cần thiết: [Required Action / None]
Deadline: [Date/Time or N/A]
```

### 2.2 Cấp Độ Ưu Tiên
- **CRITICAL**: Blocker - cần xử lý ngay lập tức (< 1 giờ)
- **HIGH**: Quan trọng - cần xử lý trong ngày (< 8 giờ)
- **MEDIUM**: Bình thường - cần xử lý trong 2 ngày
- **LOW**: Thấp - có thể xử lý theo lịch sprint

### 2.3 Đường Leo Thang (Escalation Path)
```
Agent → Tech Lead → PM → Stakeholder
```
- Mỗi cấp leo thang có SLA 4 giờ làm việc
- Phải ghi lại lý do leo thang
- Phải thông báo cho tất cả các bên liên quan

## 3. CHUẨN TÀI LIỆU (Documentation Standards)

### 3.1 Cấu Trúc Tài Liệu Bắt Buộc
Mỗi tài liệu phải có:
```markdown
# [Tiêu đề]
**Phiên bản**: X.Y.Z
**Ngày tạo**: YYYY-MM-DD
**Tác giả**: [Agent Name]
**Trạng thái**: [Draft/Review/Approved/Archived]
**Liên quan**: [Related documents]
```

### 3.2 Versioning
- Tài liệu quan trọng phải có version control
- Version format: MAJOR.MINOR.PATCH
- Breaking changes tăng MAJOR
- Thêm mới tăng MINOR
- Sửa lỗi tăng PATCH

### 3.3 Review Cycle
- Draft → Peer Review (24h) → Tech Review (24h) → Approval
- Mọi comment phải được phản hồi
- Resolved comments phải được đánh dấu

## 4. CHUẨN CODE (Code Standards)

### 4.1 Quy Tắc Chung
- Sử dụng linter và formatter được cấu hình trong project
- Code phải pass CI/CD pipeline trước khi merge
- Không commit code có TODO/FIXME mà không có ticket

### 4.2 Naming Conventions
```
Files: kebab-case (my-component.tsx)
Classes: PascalCase (UserService)
Functions/Variables: camelCase (getUserById)
Constants: UPPER_SNAKE_CASE (MAX_RETRY_COUNT)
Database tables: snake_case (user_profiles)
```

### 4.3 Code Review Requirements
- Tối thiểu 2 reviewers cho mọi PR
- Tech Lead phải review PR liên quan đến architecture
- Security-sensitive code phải được flagged và review kỹ
- Performance-critical code phải có benchmark

### 4.4 Testing Requirements
- Unit tests: Tối thiểu 80% coverage
- Integration tests: Tất cả API endpoints
- E2E tests: Happy path và critical user journeys
- Performance tests: Load testing trước mỗi release

## 5. QUẢN LÝ RỦI RO (Risk Management)

### 5.1 Phân Loại Rủi Ro
| Mức Độ | Khả Năng Xảy Ra | Tác Động | Hành Động |
|--------|-----------------|----------|-----------|
| Critical | Cao | Cao | Xử lý ngay, leo thang PM |
| High | Cao | Trung bình | Xử lý trong ngày |
| Medium | Trung bình | Trung bình | Xử lý trong sprint |
| Low | Thấp | Thấp | Ghi nhận, theo dõi |

### 5.2 Quy Trình Xử Lý Rủi Ro
1. Phát hiện rủi ro → Ghi vào Graphify risk register
2. Đánh giá mức độ → Xác định người chịu trách nhiệm
3. Lập kế hoạch mitigate → Review với Tech Lead/PM
4. Thực hiện mitigate → Cập nhật Graphify
5. Verify resolved → Đóng ticket rủi ro

## 6. BẢO MẬT (Security)

### 6.1 Quy Tắc Bảo Mật Cơ Bản
- Không bao giờ commit secrets, passwords, API keys vào git
- Sử dụng environment variables cho tất cả configuration nhạy cảm
- Encrypt data at rest và in transit
- Principle of least privilege cho tất cả permissions

### 6.2 Security Review Triggers
Bắt buộc security review khi:
- Thêm mới authentication/authorization logic
- Thay đổi data access patterns
- Thêm external dependencies mới
- Thay đổi infrastructure configuration

### 6.3 Incident Response
1. Phát hiện → Thông báo ngay cho Tech Lead và PM (CRITICAL)
2. Containment → Isolate affected systems
3. Investigation → Root cause analysis
4. Remediation → Fix và verify
5. Post-mortem → Ghi lại bài học

## 7. HIỆU SUẤT (Performance)

### 7.1 SLO (Service Level Objectives)
- API response time: P95 < 200ms, P99 < 500ms
- Frontend load time: First Contentful Paint < 1.5s
- Database query time: P95 < 100ms
- Availability: 99.9% uptime

### 7.2 Performance Monitoring
- Tất cả agents phải xem xét performance impact của changes
- Performance regression cần ngăn chặn trước khi merge
- Load testing bắt buộc cho features có high traffic

## 8. GRAPHIFY INTEGRATION RULES

### 8.1 Khi Nào Cập Nhật Graphify
- Khi bắt đầu một workflow step mới
- Khi có quyết định kiến trúc quan trọng
- Khi phát hiện dependency mới
- Khi hoàn thành một deliverable
- Khi step được approve

### 8.2 Node Types Trong Graphify
```
Requirement → Feature → Task → Code → Test → Deployment
Risk → Mitigation
Decision → Rationale → Alternative
Person → Role → Responsibility
```

## 9. GITNEXUS INTEGRATION RULES

### 9.1 Branch Naming Strategy
```
feature/[ticket-id]-short-description
bugfix/[ticket-id]-short-description
hotfix/[ticket-id]-short-description
release/v[version]
```

### 9.2 Commit Message Format (Conventional Commits)
```
type(scope): description [ticket-id]

body (optional)

footer (optional)
```
Types: feat, fix, docs, style, refactor, test, chore, perf

### 9.3 PR Requirements
- Title phải follow GitNexus format
- Description phải có: What, Why, How, Testing, Screenshots
- Tất cả CI checks phải pass
- Tất cả review comments phải được resolved

## 10. APPROVAL PROCESS

### 10.1 Approval Levels
- **Step Approval**: PM + Tech Lead
- **Code Merge**: 2 developers + Tech Lead (cho critical code)
- **Production Deploy**: PM + Tech Lead + DevOps
- **Architecture Decision**: Tech Lead + PM + Senior Dev

### 10.2 Approval Timeout
- Nếu không có response sau 24h → Leo thang lên cấp trên
- Nếu không có response sau 48h → Tự động leo thang lên PM
- Emergency: Có thể dùng emergency approval với 1 approver + ghi lý do

### 10.3 Rejection Handling
- Rejection phải có lý do cụ thể
- Người bị reject phải có 48h để address concerns
- Re-review sau khi fix không cần full cycle (chỉ verify changes)
