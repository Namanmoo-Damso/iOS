---
description: 이슈 기반으로 새로운 feature 브랜치를 생성하고 작업을 시작합니다
---

# /start-work - 이슈 작업 시작

> **참고:** 브랜치 전략은 `CLAUDE.md`를 따릅니다.
> **언어:** 모든 결과는 **한글**로 보고합니다.

---

## 0. 현재 상태 확인

```bash
# 현재 브랜치 및 상태 확인
git status
git branch --show-current
```

**변경사항이 있는 경우**: 먼저 커밋하거나 stash 할 것을 안내 후 **중단**

---

## 1. 이슈 목록 조회 (인자 없이 실행 시)

인자가 없으면 현재 열린 이슈 목록을 보여줍니다:

```bash
gh issue list --state open --json number,title,labels --limit 20
```

**출력 형식**:
```
📋 열린 이슈 목록:
#8  [Feature] 1. 사용자 모델 정의 (User, Guardian, Ward)
#9  [Feature] 2. 카카오 로그인 + 서버 JWT 발급
...

사용법: /start-work <이슈번호>
예시: /start-work 8
```

---

## 2. 이슈 상세 조회 (인자 있을 때)

```bash
ISSUE_NUM=$1  # 첫 번째 인자

# 이슈 정보 가져오기
gh issue view $ISSUE_NUM --json number,title,body,labels
```

---

## 3. 브랜치 생성

```bash
# 이슈 제목에서 브랜치명 생성
# 예: "[Feature] 1. 사용자 모델 정의" → "feature/8-user-model"

# develop 브랜치에서 분기
git checkout develop
git pull origin develop

# 새 브랜치 생성
git checkout -b feature/${ISSUE_NUM}-<short-description>
```

**브랜치 네이밍 규칙**:
- Feature: `feature/{issue-number}-{short-desc}`
- Bug fix: `fix/{issue-number}-{short-desc}`
- Hotfix: `hotfix/{short-desc}`

---

## 4. 이슈 상태 업데이트 (선택)

```bash
# GitHub Project에서 상태를 "In Progress"로 변경 (프로젝트 연동 시)
gh issue edit $ISSUE_NUM --add-label "in-progress" 2>/dev/null || true
```

---

## 5. 작업 컨텍스트 로드

이슈 본문을 분석하여 다음을 파악:

1. **구현 범위**: 어떤 파일/기능을 만들어야 하는지
2. **의존성**: 이전 이슈에서 만든 것 중 필요한 것
3. **테스트 요구사항**: 어떤 테스트가 필요한지

```bash
# 관련 기존 코드 탐색
find damso -name "*.swift" -type f | head -30

# 기존 모델/서비스 확인
ls -la damso/Models/ 2>/dev/null || echo "Models 폴더 없음"
ls -la damso/Services/
ls -la damso/ViewModels/
```

---

## 6. 최종 보고

| 항목 | 값 |
|------|-----|
| 이슈 번호 | `#${ISSUE_NUM}` |
| 이슈 제목 | `<title>` |
| 생성된 브랜치 | `feature/${ISSUE_NUM}-<desc>` |
| Base 브랜치 | `develop` |
| 다음 단계 | 구현 시작 |

---

## 흐름도

```
/start-work
    │
    ▼
인자 있음? ──No──▶ 이슈 목록 출력 후 종료
    │
    ▼ Yes
변경사항 있음? ──Yes──▶ 커밋/stash 안내 후 중단
    │
    ▼ No
develop checkout & pull
    │
    ▼
feature 브랜치 생성
    │
    ▼
이슈 컨텍스트 로드
    │
    ▼
최종 보고 → 구현 준비 완료
```
