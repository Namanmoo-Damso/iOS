---
description: 현재 PR을 코드 리뷰하고 충돌 확인 후 머지합니다
---

# /review-merge - PR 리뷰 & 머지

> **참고:** 코드 리뷰 기준은 `CLAUDE.md`를 따릅니다.
> **언어:** 모든 결과는 **한글**로 보고합니다.

---

## 0. 현재 PR 확인

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_INFO=$(gh pr view --json number,title,state,baseRefName,url,mergeable,mergeStateStatus 2>/dev/null)
```

**PR이 없는 경우**: "현재 브랜치에 연결된 PR이 없습니다. /commit-push-pr을 먼저 실행하세요." 안내 후 **중단**

---

## 1. PR 정보 출력

```bash
gh pr view --json number,title,state,baseRefName,additions,deletions,changedFiles
```

| 항목 | 값 |
|------|-----|
| PR 번호 | `#<number>` |
| 제목 | `<title>` |
| 상태 | `<state>` |
| Base | `<baseRefName>` |
| 변경 | `+<additions> -<deletions>` |
| 파일 수 | `<changedFiles>` |

---

## 2. 코드 리뷰 수행

### 2-1. 변경된 파일 목록 확인

```bash
gh pr diff --name-only
```

### 2-2. 변경 내용 분석

```bash
gh pr diff
```

### 2-3. 코드 리뷰 체크리스트

**🔴 치명적 (즉시 수정 필요)**:
- [ ] Force unwrap (`!`) 사용 여부
- [ ] 메모리 순환 참조 가능성
- [ ] 민감 정보 하드코딩
- [ ] Main thread 블로킹

**⚠️ 경고 (권장 수정)**:
- [ ] View에서 비즈니스 로직
- [ ] 테스트 코드 누락
- [ ] Protocol 없이 Service 사용
- [ ] 500줄 이상 파일

**💡 제안 (선택)**:
- [ ] 더 나은 Swift 패턴
- [ ] 코드 정리 기회

---

## 3. 코드 리뷰 결과 보고

### 치명적 이슈가 있는 경우

```
🔴 **코드 리뷰 실패** - 다음 이슈를 수정해주세요:

1. `파일명:라인` - 이슈 설명
   ```swift
   // 문제 코드
   ```
   **수정 방안**: ...

머지를 진행할 수 없습니다. 수정 후 다시 /review-merge를 실행하세요.
```

### 경고만 있는 경우

```
⚠️ **코드 리뷰 경고** - 권장 수정 사항:

1. `파일명:라인` - 이슈 설명

머지는 가능하지만, 수정을 권장합니다.
계속 진행하시겠습니까? (y/n)
```

### 이슈 없는 경우

```
✅ **코드 리뷰 통과** - 수정 필요 사항 없음

머지를 진행합니다.
```

---

## 4. Merge Conflict 확인

```bash
# Mergeable 상태 확인
MERGEABLE=$(gh pr view --json mergeable --jq '.mergeable')
MERGE_STATE=$(gh pr view --json mergeStateStatus --jq '.mergeStateStatus')
```

| mergeable | mergeStateStatus | 상태 |
|-----------|------------------|------|
| `MERGEABLE` | `CLEAN` | ✅ 머지 가능 |
| `CONFLICTING` | - | ❌ 충돌 있음 |
| `UNKNOWN` | `BLOCKED` | ⏳ 확인 중 |

**충돌이 있는 경우**:
```bash
# 충돌 해결 안내
echo "⚠️ Merge conflict가 있습니다. 다음 단계를 따라 해결하세요:"
echo "1. git fetch origin develop"
echo "2. git merge origin/develop"
echo "3. 충돌 파일 수정"
echo "4. git add . && git commit"
echo "5. git push"
echo "6. /review-merge 다시 실행"
```

---

## 5. 머지 실행

```bash
# Squash and Merge 권장 (깔끔한 커밋 히스토리)
gh pr merge --squash --delete-branch
```

**머지 옵션**:
- `--squash`: 모든 커밋을 하나로 합침 (권장)
- `--merge`: 일반 머지 커밋
- `--rebase`: 리베이스 머지
- `--delete-branch`: 머지 후 원격 브랜치 삭제

---

## 6. 머지 후 정리

```bash
# 로컬 브랜치 정리
git checkout develop
git pull origin develop
git branch -d $CURRENT_BRANCH 2>/dev/null || true

# 연결된 이슈 자동 닫힘 확인
# (PR 본문에 "Closes #N"이 있으면 자동으로 닫힘)
```

---

## 7. 최종 보고

| 항목 | 값 |
|------|-----|
| PR 번호 | `#<number>` |
| 코드 리뷰 | ✅ 통과 / ⚠️ 경고 / 🔴 실패 |
| Merge Conflict | 없음 / 있음 (해결됨) |
| 머지 상태 | ✅ 완료 / ❌ 실패 |
| 삭제된 브랜치 | `<branch-name>` |
| 닫힌 이슈 | `#<issue-number>` |

---

## 흐름도

```
/review-merge
    │
    ▼
PR 존재? ──No──▶ /commit-push-pr 안내 후 중단
    │
    ▼ Yes
코드 리뷰 수행
    │
    ▼
🔴 치명적? ──Yes──▶ 수정 요청 후 중단
    │
    ▼ No
⚠️ 경고? ──Yes──▶ 경고 표시, 계속 여부 확인
    │
    ▼ (계속)
Merge Conflict? ──Yes──▶ 충돌 해결 안내 후 중단
    │
    ▼ No
Squash & Merge
    │
    ▼
브랜치 정리
    │
    ▼
최종 보고
```
