#!/bin/bash

# =============================================================================
# commit-push-pr.sh - 스마트 커밋, 푸시, PR 생성/업데이트 스크립트
# 사용법: ./scripts/commit-push-pr.sh
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# 0. 브랜치 전략 확인
# =============================================================================

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "main" ]]; then
    error "main 브랜치에 직접 push할 수 없습니다."
    echo "feature 브랜치를 생성하세요: git checkout -b feature/<기능명>"
    exit 1
fi

if [[ "$CURRENT_BRANCH" == "develop" ]]; then
    error "develop 브랜치에 직접 push할 수 없습니다."
    echo "feature 브랜치를 생성하세요: git checkout -b feature/<기능명>"
    exit 1
fi

info "현재 브랜치: ${CURRENT_BRANCH}"

# =============================================================================
# 1. 변경사항 확인
# =============================================================================

HAS_CHANGES=false

if [[ -n $(git status --porcelain) ]]; then
    HAS_CHANGES=true
    info "변경사항 확인됨"
    git status --short
fi

# =============================================================================
# 2. Target Branch 결정
# =============================================================================

if [[ "$CURRENT_BRANCH" == hotfix/* ]]; then
    TARGET_BRANCH="main"
else
    TARGET_BRANCH="develop"
fi

info "Target 브랜치: ${TARGET_BRANCH}"

# =============================================================================
# 3. 커밋 & 푸시 (변경사항 있는 경우)
# =============================================================================

COMMIT_MSG=""

if [ "$HAS_CHANGES" = true ]; then
    info "변경사항 스테이징..."
    git add .

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 커밋 메시지를 입력하세요 (Conventional Commits 형식)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "형식: <type>(<scope>): <description>"
    echo ""
    echo "타입:"
    echo "  feat     새 기능"
    echo "  fix      버그 수정"
    echo "  refactor 리팩토링"
    echo "  test     테스트"
    echo "  docs     문서"
    echo "  chore    설정/빌드"
    echo ""
    echo "예시: feat(auth): 카카오 로그인 서비스 구현"
    echo ""
    read -p "커밋 메시지: " COMMIT_MSG

    if [ -z "$COMMIT_MSG" ]; then
        error "커밋 메시지가 비어있습니다."
        exit 1
    fi

    git commit -m "$COMMIT_MSG"
    success "커밋 완료"

    info "푸시 중..."
    git push -u origin "$CURRENT_BRANCH"
    success "푸시 완료"
fi

# =============================================================================
# 4. PR 존재 여부 확인
# =============================================================================

info "PR 상태 확인 중..."

PR_URL=$(gh pr view --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || echo "")

# =============================================================================
# 5. 이슈 번호 추출
# =============================================================================

ISSUE_NUM=$(echo "$CURRENT_BRANCH" | grep -oE '/[0-9]+' | tr -d '/' | head -1)

if [ -n "$ISSUE_NUM" ]; then
    ISSUE_TITLE=$(gh issue view $ISSUE_NUM --json title --jq '.title' 2>/dev/null || echo "")
    info "연결된 이슈: #${ISSUE_NUM} - ${ISSUE_TITLE}"
fi

# =============================================================================
# 6. PR 생성 또는 업데이트
# =============================================================================

if [ -z "$PR_URL" ]; then
    # PR 없음 - 신규 생성
    info "PR 신규 생성..."

    # 커밋 로그 확인
    git fetch origin $TARGET_BRANCH
    COMMITS=$(git log origin/$TARGET_BRANCH..$CURRENT_BRANCH --oneline)

    if [ -z "$COMMITS" ]; then
        warning "base 브랜치 대비 새로운 커밋이 없습니다."
        exit 0
    fi

    # 변경 파일 목록
    CHANGED_FILES=$(git diff --name-only origin/$TARGET_BRANCH..$CURRENT_BRANCH)

    # PR 제목 생성
    if [ -n "$ISSUE_NUM" ] && [ -n "$ISSUE_TITLE" ]; then
        PR_TITLE="#${ISSUE_NUM} - ${ISSUE_TITLE}"
    else
        PR_TITLE="${CURRENT_BRANCH}"
    fi

    # PR 본문 생성
    PR_BODY="## 📋 변경 사항

${COMMITS}

## 📁 변경된 파일

\`\`\`
${CHANGED_FILES}
\`\`\`

## ✅ 체크리스트

- [ ] 빌드 성공 확인
- [ ] 테스트 통과 확인
- [ ] CLAUDE.md 코딩 규칙 준수
"

    # 이슈 연결 추가
    if [ -n "$ISSUE_NUM" ]; then
        PR_BODY="${PR_BODY}
## 🔗 관련 이슈

Closes #${ISSUE_NUM}
"
    fi

    PR_BODY="${PR_BODY}
---
🤖 Generated with [Claude Code](https://claude.com/claude-code)"

    # PR 생성
    NEW_PR_URL=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --base "$TARGET_BRANCH")

    success "PR 생성 완료"
    PR_URL="$NEW_PR_URL"
    PR_STATUS="신규 생성"

else
    # PR 있음 - 업데이트
    info "기존 PR 업데이트..."

    # 최신 커밋 로그
    git fetch origin $TARGET_BRANCH
    COMMITS=$(git log origin/$TARGET_BRANCH..$CURRENT_BRANCH --oneline)
    CHANGED_FILES=$(git diff --name-only origin/$TARGET_BRANCH..$CURRENT_BRANCH)

    # PR 제목 업데이트
    if [ -n "$ISSUE_NUM" ] && [ -n "$ISSUE_TITLE" ]; then
        PR_TITLE="#${ISSUE_NUM} - ${ISSUE_TITLE}"
        gh pr edit --title "$PR_TITLE" 2>/dev/null || true
    fi

    success "PR 업데이트 완료 (push로 자동 반영됨)"
    PR_STATUS="업데이트"
fi

# =============================================================================
# 7. 최종 보고
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "작업 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 브랜치: ${CURRENT_BRANCH}"
echo "📝 커밋: ${COMMIT_MSG:-변경 없음}"
echo "🚀 푸시: $([ "$HAS_CHANGES" = true ] && echo "완료" || echo "변경 없음")"
echo "📋 PR 상태: ${PR_STATUS:-확인됨}"
echo "🔗 PR URL: ${PR_URL}"
if [ -n "$ISSUE_NUM" ]; then
    echo "🎯 연결된 이슈: #${ISSUE_NUM}"
fi
echo "🎯 Target: ${TARGET_BRANCH}"
echo ""
echo "다음 단계:"
echo "  ./scripts/review-merge.sh 실행"
echo ""
