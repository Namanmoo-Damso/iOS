---
description: 현재 이슈 완료 후 다음 이슈로 자동 전환합니다
---

# /next-issue - 다음 이슈로 이동

> **참고:** 이슈 순서는 `CLAUDE.md`의 issue_tracker를 따릅니다.
> **언어:** 모든 결과는 **한글**로 보고합니다.

---

## 0. 현재 상태 확인

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 현재 브랜치에서 이슈 번호 추출
CURRENT_ISSUE=$(echo "$CURRENT_BRANCH" | grep -oE '/[0-9]+' | tr -d '/')
```

---

## 1. 현재 이슈 완료 확인

```bash
# 현재 이슈의 PR 상태 확인
gh pr view --json state,merged --jq '{state: .state, merged: .merged}' 2>/dev/null
```

| PR 상태 | 조치 |
|---------|------|
| MERGED | ✅ 완료 - 다음 이슈로 진행 |
| OPEN | ⚠️ "아직 머지되지 않았습니다. /review-merge를 먼저 실행하세요." |
| 없음 | ⚠️ "PR이 없습니다. /commit-push-pr을 먼저 실행하세요." |

---

## 2. 다음 이슈 결정

**이슈 우선순위 순서** (CLAUDE.md 기준):

```
#8  → #9  → #10 → #11 → #12 → #13 → #14 →
#15 → #16 → #17 → #18 → #19 → #20 → #21 →
#22 → #23 → #24
```

```bash
# 다음 이슈 번호 계산
ISSUE_ORDER=(8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24)

for i in "${!ISSUE_ORDER[@]}"; do
  if [[ "${ISSUE_ORDER[$i]}" == "$CURRENT_ISSUE" ]]; then
    NEXT_ISSUE="${ISSUE_ORDER[$((i+1))]}"
    break
  fi
done
```

**마지막 이슈인 경우**: "🎉 모든 이슈가 완료되었습니다!" 안내 후 종료

---

## 3. 다음 이슈 정보 조회

```bash
gh issue view $NEXT_ISSUE --json number,title,body,labels,state
```

**이슈가 이미 닫힌 경우**: 그 다음 열린 이슈 탐색

---

## 4. 로컬 브랜치 정리

```bash
# develop으로 이동
git checkout develop
git pull origin develop

# 이전 로컬 브랜치 삭제 (선택)
git branch -d $CURRENT_BRANCH 2>/dev/null || true
```

---

## 5. 새 브랜치 생성

```bash
# 다음 이슈용 브랜치 생성
git checkout -b feature/${NEXT_ISSUE}-<short-description>
```

---

## 6. 다음 이슈 컨텍스트 로드

이슈 본문을 분석하여 다음을 파악:

1. **구현 범위**: 어떤 파일/기능을 만들어야 하는지
2. **의존성**: 이전 이슈에서 만든 것 중 필요한 것
3. **관련 파일**: 수정/생성해야 할 파일 목록

---

## 7. 진행 상황 보고

```
📊 **진행 상황**

완료된 이슈: #8, #9, ... #${CURRENT_ISSUE}
다음 이슈: #${NEXT_ISSUE}
남은 이슈: N개

──────────────────────────────

📋 **다음 이슈 정보**

번호: #${NEXT_ISSUE}
제목: <title>
브랜치: feature/${NEXT_ISSUE}-<desc>

──────────────────────────────

🚀 **다음 단계**

구현을 시작합니다. 필요한 컨텍스트:
- 관련 파일: ...
- 의존성: ...
```

---

## 8. 전체 워크플로우 요약

```
┌─────────────────────────────────────────────────────┐
│                  이슈 워크플로우                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  /start-work <N>     이슈 작업 시작, 브랜치 생성      │
│        ↓                                            │
│  [구현 작업]          코드 작성, 테스트               │
│        ↓                                            │
│  /commit-push-pr     커밋, 푸시, PR 생성            │
│        ↓                                            │
│  /review-merge       코드 리뷰, 충돌 확인, 머지      │
│        ↓                                            │
│  /next-issue         다음 이슈로 자동 전환           │
│        ↓                                            │
│  (반복)                                             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 흐름도

```
/next-issue
    │
    ▼
현재 PR 머지됨? ──No──▶ /review-merge 안내 후 중단
    │
    ▼ Yes
다음 이슈 번호 계산
    │
    ▼
마지막 이슈? ──Yes──▶ 🎉 완료 메시지 후 종료
    │
    ▼ No
develop checkout & pull
    │
    ▼
새 feature 브랜치 생성
    │
    ▼
이슈 컨텍스트 로드
    │
    ▼
진행 상황 보고 → 구현 시작
```
