# Quy Tắc Workflow - IT Product Development
# Workflow Rules for Step Execution

## 1. CẤU TRÚC WORKFLOW TỔNG QUAN

```
Step 1: Requirements Analysis  →  [PM + Tech Lead]
         ↓ [APPROVAL GATE]
Step 2: System Design          →  [Tech Lead + Backend Dev]
         ↓ [APPROVAL GATE]
Step 3: UI/UX Design           →  [UI/UX + Frontend Dev]
         ↓ [APPROVAL GATE]
Step 4: Backend Development    →  [Backend Dev + Tech Lead]
         ↓ [APPROVAL GATE]
Step 5: Frontend Development   →  [Frontend Dev + UI/UX]
         ↓ [APPROVAL GATE]
Step 6: Integration Testing    →  [Tech Lead + All Devs]
         ↓ [APPROVAL GATE]
Step 7: QA Testing             →  [QA + All Devs]
         ↓ [APPROVAL GATE]
Step 8: DevOps & Deployment    →  [DevOps + Tech Lead]
         ↓ [APPROVAL GATE]
Step 9: Review & Release       →  [PM + Tech Lead + All]
         ↓ [FINAL APPROVAL]
```

## 2. QUY TẮC BẮT ĐẦU STEP (Step Entry Rules)

### 2.1 Điều Kiện Bắt Đầu
Trước khi bắt đầu bất kỳ step nào, agent phải verify:
- [ ] Step trước đã được APPROVED (trừ Step 1)
- [ ] Approval document đã được tạo và ký
- [ ] Tất cả blockers từ step trước đã được resolve
- [ ] Graphify đã được cập nhật với kết quả step trước
- [ ] Tất cả artifacts từ step trước đã được commit vào git

### 2.2 Quy Trình Khởi Động Step
```
1. Agent kiểm tra điều kiện bắt đầu
2. Query Graphify để load context từ các steps trước
3. Query GitNexus để hiểu trạng thái codebase hiện tại
4. Tạo branch mới theo GitNexus naming convention
5. Tạo step plan document
6. Thông báo cho tất cả agents liên quan
7. Bắt đầu thực hiện step
```

### 2.3 Step Kickoff Document
Mỗi step phải tạo kickoff document với format:
```markdown
# Step [N]: [Step Name] - Kickoff
**Ngày bắt đầu**: YYYY-MM-DD
**Lead Agent**: [Agent Name]
**Support Agents**: [Agent Names]
**Estimated Duration**: [X days]
**Previous Step Approval**: [Link to approval doc]

## Objectives
[List objectives]

## Graphify Context Loaded
[Key insights from Graphify query]

## GitNexus Branch
[Branch name and strategy]

## Plan
[Detailed step plan]
```

## 3. QUY TẮC THỰC HIỆN STEP (Step Execution Rules)

### 3.1 Daily Progress Updates
- Cập nhật hàng ngày trước 5pm
- Format: [Progress %] - [What done] - [Blockers] - [Next]
- Post trong step document

### 3.2 Decision Logging
Mọi quyết định quan trọng phải được ghi lại:
```markdown
## Decision Record [DR-YYYYMMDD-NNN]
**Ngày**: YYYY-MM-DD
**Người quyết định**: [Agent + Human approval if needed]
**Vấn đề**: [Problem statement]
**Các lựa chọn đã xem xét**:
  1. Option A - Pros/Cons
  2. Option B - Pros/Cons
**Quyết định**: [Chosen option]
**Lý do**: [Rationale]
**Tác động**: [Impact on other steps/components]
**Graphify Update**: [Node/relationship added]
```

### 3.3 Blocker Management
Khi gặp blocker:
1. Ngay lập tức ghi vào step document
2. Thông báo cho lead agent và Tech Lead
3. Nếu blocker > 4 giờ → Leo thang lên PM
4. Tìm workaround nếu có thể
5. Cập nhật timeline nếu cần

### 3.4 Scope Management
- Scope thay đổi phải được approved bởi PM
- Thay đổi nhỏ (< 2 giờ effort): Tech Lead approve
- Thay đổi vừa (2-8 giờ effort): PM approve
- Thay đổi lớn (> 8 giờ effort): Formal change request

## 4. QUY TẮC KẾT THÚC STEP (Step Completion Rules)

### 4.1 Definition of Done (DoD)
Mỗi step phải thỏa mãn DoD riêng của nó (xem step document).
DoD chung cho mọi step:
- [ ] Tất cả deliverables đã được hoàn thành
- [ ] Tất cả tests (nếu có) đã pass
- [ ] Tài liệu đã được cập nhật
- [ ] Graphify đã được cập nhật
- [ ] GitNexus đã commit tất cả changes
- [ ] Step summary đã được tạo
- [ ] Review checklist đã được điền
- [ ] Approval request đã được gửi

### 4.2 Step Summary Requirements
Step summary phải bao gồm:
```markdown
1. Executive Summary (cho PM, không kỹ thuật)
2. Technical Summary (cho Tech Lead và Devs)
3. Deliverables List (với link/location)
4. Metrics & KPIs đạt được
5. Issues & Resolutions
6. Risks Identified & Mitigation
7. Dependencies for Next Step
8. Lessons Learned
9. Graphify Knowledge Graph Update Summary
10. GitNexus Activity Summary
```

### 4.3 Handoff Protocol
Khi chuyển sang step tiếp theo:
1. Lead agent của step hiện tại brief lead agent của step tiếp theo
2. Briefing phải cover: context, decisions made, known issues, dependencies
3. Tất cả artifacts phải accessible
4. Graphify context phải được chia sẻ
5. Có thể có overlap period (1-2 ngày) cho smooth handoff

## 5. APPROVAL GATE PROCESS

### 5.1 Quy Trình Approval
```
Step Complete
    ↓
Agent tạo Approval Request Document
    ↓
Gửi cho Reviewers (PM + Tech Lead cho hầu hết steps)
    ↓
Review Period: 24-48h
    ↓
[APPROVED] → Proceed to next step
[REJECTED] → Address concerns → Re-submit
[CONDITIONAL] → Fix specific issues → Conditional Approval
```

### 5.2 Approval Request Document Format
Sử dụng template tại: workflows/templates/approval-request-template.md

### 5.3 Review Criteria
Reviewers sẽ đánh giá:
1. **Completeness**: Tất cả deliverables đã hoàn thành?
2. **Quality**: Chất lượng đáp ứng standards?
3. **Accuracy**: Đúng với requirements?
4. **Risk**: Có rủi ro nào cần address?
5. **Dependencies**: Mọi dependency cho step tiếp theo đã sẵn sàng?

### 5.4 Approval Statuses
- **APPROVED**: Đủ điều kiện tiến sang step tiếp theo
- **APPROVED WITH CONDITIONS**: Tiến sang step tiếp theo nhưng phải fix các issues được liệt kê trong 48h
- **REJECTED**: Phải address tất cả concerns và submit lại
- **DEFERRED**: Cần thêm thông tin, trả lại trong 24h

## 6. QUY TẮC XỬ LÝ SONG SONG (Parallel Execution Rules)

### 6.1 Các Steps Có Thể Chạy Song Song
- Step 3 (UI/UX) và Step 2 (System Design) có thể overlap
- Step 4 (Backend) và Step 5 (Frontend) có thể chạy song song sau khi API contract được define
- Test preparation (Step 7) có thể bắt đầu trong Step 6

### 6.2 Điều Kiện Cho Parallel Execution
- Phải có explicit approval từ PM và Tech Lead
- Phải có clear interface contracts giữa parallel workstreams
- Integration checkpoints phải được lên lịch
- Rủi ro của parallel execution phải được documented

### 6.3 Dependency Management Trong Parallel Execution
- Sử dụng Graphify để track cross-workstream dependencies
- Daily sync giữa lead agents của parallel workstreams
- Conflict resolution: Tech Lead quyết định

## 7. METRICS VÀ MONITORING

### 7.1 Step Metrics
Mỗi step phải track:
- **Velocity**: Actual vs. Planned effort
- **Quality**: Defect density, rework rate
- **Timeline**: On-time delivery rate
- **Scope**: Scope change count và impact

### 7.2 Workflow Health Dashboard
Cập nhật hàng ngày trong Graphify:
```
Overall Progress: [N/9 steps complete]
Current Step: [Step N - Status]
Blockers: [Count]
At-Risk Items: [Count]
Days to Release: [N]
Quality Gate Status: [Pass/Fail]
```

### 7.3 Retrospective
Sau mỗi step:
- 15-minute retrospective với team
- 3 things went well, 3 things to improve
- Action items được assign và tracked

## 8. EMERGENCY PROCEDURES

### 8.1 Production Hotfix
Nếu có production issue trong khi workflow đang chạy:
1. PM quyết định suspend workflow hay không
2. Hotfix branch được tạo từ production
3. Fastest path to fix: DevOps + Tech Lead + relevant Dev
4. Deploy to production sau QA sign-off
5. Merge hotfix back vào workflow branch

### 8.2 Workflow Reset
Nếu cần reset về step trước:
1. PM phải approve workflow reset
2. Document lý do reset
3. Cập nhật Graphify với rollback information
4. Create rollback branch trong GitNexus
5. Thông báo toàn bộ team

### 8.3 Scope Freeze
Khi vào giai đoạn cuối (Step 7+):
- Scope freeze được enforce
- Chỉ critical bugs được fix
- Feature requests → Backlog cho next iteration
- PM có quyền veto tất cả scope changes
