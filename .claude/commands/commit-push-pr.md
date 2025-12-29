---
description: 변경사항 분석, 커밋, 푸시 후 PR 상태를 확인하여 생성하거나 업데이트합니다
---

# /commit-push-pr - 스마트 커밋 & PR

> **참고:** 커밋 컨벤션은 `CLAUDE.md`를 따릅니다.
> **언어:** 모든 결과 보고 및 PR 본문은 **한글**로 작성합니다.

---

## 0. 브랜치 전략 준수 확인 (필수!)

**⚠️ 직접 push 금지 브랜치**: `main`, `develop`

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

| 현재 브랜치 | push 가능? | 조치 |
|------------|-----------|------|
| `main` | ❌ 금지 | "main에 직접 push할 수 없습니다. feature 브랜치를 생성하세요." 안내 후 **중단** |
| `develop` | ❌ 금지 | "develop에 직접 push할 수 없습니다. feature 브랜치를 생성하세요." 안내 후 **중단** |
| `feature/*`, `fix/*`, `hotfix/*` | ✅ 허용 | 계속 진행 |

---

## 1. 현재 상태 및 변경사항 확인

```bash
git status
git diff --stat
git diff --staged --stat
```

- 변경사항이 없으면 "커밋할 내용이 없습니다" 안내 후 **3단계로 건너뛰기**

---

## 2. 스테이징 및 커밋

**변경사항이 있는 경우에만 실행**:

```bash
# 모든 변경사항 스테이징
git add .

# diff 분석 기반 Conventional Commit 메시지 생성
# 예: feat(auth): 카카오 로그인 서비스 구현
git commit -m "<type>(<scope>): <한글 설명>"

# 원격에 푸시
git push origin $CURRENT_BRANCH
```

**커밋 메시지 규칙**:
- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 리팩토링
- `test`: 테스트 추가
- `docs`: 문서 변경
- `chore`: 설정/빌드 변경

---

## 3. Target Branch 결정

| 현재 브랜치 패턴 | Target Branch |
|----------------|---------------|
| `hotfix/*` | `main` |
| `feature/*`, `fix/*`, 기타 | `develop` |

```bash
if [[ "$CURRENT_BRANCH" == hotfix/* ]]; then
  TARGET_BRANCH="main"
else
  TARGET_BRANCH="develop"
fi
```

---

## 4. PR 존재 여부 확인 (필수!)

```bash
PR_URL=$(gh pr view --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || echo "")
```

| 결과 | 상태 |
|-----|------|
| URL 있음 | PR이 이미 존재 → **4-B로** (업데이트) |
| 비어있음 | PR 없음 → **4-A로** (생성) |

---

## 4-A. PR 신규 생성 (PR이 없는 경우)

### Step 1: 원격과의 차이 확인

```bash
git fetch origin $TARGET_BRANCH
COMMITS=$(git log origin/$TARGET_BRANCH..$CURRENT_BRANCH --oneline)
```

- 커밋이 없으면: "base 브랜치 대비 새로운 커밋이 없습니다." 보고 후 종료

### Step 2: 이슈 번호 추출

```bash
# 브랜치명에서 이슈 번호 추출 (예: feature/8-user-model → 8)
ISSUE_NUM=$(echo "$CURRENT_BRANCH" | grep -oE '/[0-9]+' | tr -d '/')
```

### Step 3: PR 본문 작성

`.pr_body_temp.md` 파일 생성:

```markdown
## 📋 변경 사항

<커밋 기반 변경 내용 요약 - 한글로 작성>

## 📁 변경된 파일

<파일 목록>

## ✅ 체크리스트

- [ ] 빌드 성공 확인 (`xcodebuild build`)
- [ ] 테스트 통과 확인
- [ ] CLAUDE.md 코딩 규칙 준수

## 🔗 관련 이슈

Closes #<ISSUE_NUM>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Step 4: PR 생성

```bash
gh pr create \
  --title "[Feature] #$ISSUE_NUM - <이슈 제목 요약>" \
  --body-file .pr_body_temp.md \
  --base $TARGET_BRANCH

rm .pr_body_temp.md
```

---

## 4-B. 기존 PR 업데이트 (PR이 있는 경우)

### Step 1: 변경 내역 분석

```bash
git fetch origin $TARGET_BRANCH
git log origin/$TARGET_BRANCH..$CURRENT_BRANCH --oneline
```

### Step 2: PR 본문 재작성

`.pr_body_temp.md` 파일에 최신 변경사항 반영

### Step 3: PR 업데이트

```bash
gh pr edit \
  --title "[Feature] #$ISSUE_NUM - <업데이트된 제목>" \
  --body-file .pr_body_temp.md

rm .pr_body_temp.md
```

---

## 5. 최종 보고

| 항목 | 값 |
|------|-----|
| 브랜치 | `$CURRENT_BRANCH` |
| 커밋 | O / X (커밋 메시지) |
| 푸시 | O / X |
| PR 상태 | 신규 생성 / 업데이트 / 변경없음 |
| PR URL | `<URL>` |
| 연결된 이슈 | `#<ISSUE_NUM>` |
| Target | `$TARGET_BRANCH` |

---

## ⚠️ 주의사항

1. **main/develop에 직접 push 금지** - feature 브랜치 사용 필수
2. **PR 본문 없이 생성 금지** - 항상 상세 본문 작성
3. **이슈 연결 필수** - `Closes #N` 형식으로 연결
4. **한글 메시지** - 커밋, PR 모두 한글로 작성

---

## 흐름도

```
/commit-push-pr
    │
    ▼
브랜치 확인 ──main/develop──▶ ❌ 중단
    │
    ▼ (feature/fix/hotfix)
변경사항 있음? ──No──▶ 3단계로
    │
    ▼ Yes
git add . && commit && push
    │
    ▼
Target 결정 (develop/main)
    │
    ▼
PR 존재? ──Yes──▶ 4-B: PR 업데이트
    │
    ▼ No
4-A: PR 신규 생성
    │
    ▼
최종 보고
```
