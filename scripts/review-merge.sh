#!/bin/bash

# =============================================================================
# review-merge.sh - PR 리뷰 및 머지 스크립트
# 사용법: ./scripts/review-merge.sh
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
# 0. PR 존재 확인
# =============================================================================

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

PR_INFO=$(gh pr view --json number,title,state,baseRefName,url,mergeable,additions,deletions,changedFiles 2>/dev/null || echo "")

if [ -z "$PR_INFO" ]; then
    error "현재 브랜치에 연결된 PR이 없습니다."
    echo "먼저 ./scripts/commit-push-pr.sh를 실행하세요."
    exit 1
fi

PR_STATE=$(echo "$PR_INFO" | jq -r '.state')
if [ "$PR_STATE" != "OPEN" ]; then
    warning "PR 상태가 OPEN이 아닙니다: ${PR_STATE}"
    exit 1
fi

PR_NUMBER=$(echo "$PR_INFO" | jq -r '.number')
PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_URL=$(echo "$PR_INFO" | jq -r '.url')
PR_BASE=$(echo "$PR_INFO" | jq -r '.baseRefName')
PR_ADDITIONS=$(echo "$PR_INFO" | jq -r '.additions')
PR_DELETIONS=$(echo "$PR_INFO" | jq -r '.deletions')
PR_FILES=$(echo "$PR_INFO" | jq -r '.changedFiles')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 PR 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "번호: #${PR_NUMBER}"
echo "제목: ${PR_TITLE}"
echo "Base: ${PR_BASE}"
echo "변경: +${PR_ADDITIONS} -${PR_DELETIONS} (${PR_FILES} files)"
echo "URL: ${PR_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# 1. 코드 리뷰 체크리스트
# =============================================================================

info "코드 리뷰 체크리스트"
echo ""

# 변경된 파일 목록
CHANGED_FILES=$(gh pr diff --name-only)

echo "📁 변경된 파일:"
echo "$CHANGED_FILES" | while read file; do
    echo "   - $file"
done
echo ""

# 간단한 코드 검사
echo "🔍 자동 검사 중..."

ISSUES_FOUND=false
CRITICAL_ISSUES=""
WARNING_ISSUES=""

# Force unwrap 검사
if gh pr diff | grep -n '!' | grep -v '!=' | grep -v '//' | head -5 > /dev/null 2>&1; then
    FORCE_UNWRAP=$(gh pr diff | grep -n '!' | grep -v '!=' | grep -v '//' | head -5)
    if [ -n "$FORCE_UNWRAP" ]; then
        # Swift 파일에서만 검사 (! 가 Force unwrap인 경우)
        if echo "$CHANGED_FILES" | grep -q '\.swift$'; then
            warning "Force unwrap (!) 사용 의심 - 직접 확인 필요"
        fi
    fi
fi

# TODO/FIXME 검사
if gh pr diff | grep -E 'TODO|FIXME' > /dev/null 2>&1; then
    warning "TODO/FIXME 코멘트가 있습니다."
fi

# print() 사용 검사
if gh pr diff | grep -E '^\+.*print\(' > /dev/null 2>&1; then
    warning "print() 사용 - Logger로 대체 권장"
fi

echo ""

# =============================================================================
# 2. Merge Conflict 확인
# =============================================================================

info "Merge Conflict 확인 중..."

MERGEABLE=$(echo "$PR_INFO" | jq -r '.mergeable')

if [ "$MERGEABLE" == "CONFLICTING" ]; then
    error "Merge conflict가 있습니다!"
    echo ""
    echo "해결 방법:"
    echo "  1. git fetch origin ${PR_BASE}"
    echo "  2. git merge origin/${PR_BASE}"
    echo "  3. 충돌 파일 수정"
    echo "  4. git add . && git commit -m 'resolve: merge conflict 해결'"
    echo "  5. git push"
    echo "  6. ./scripts/review-merge.sh 다시 실행"
    exit 1
elif [ "$MERGEABLE" == "UNKNOWN" ]; then
    warning "Merge 상태 확인 중... 잠시 후 다시 시도하세요."
    exit 1
fi

success "Merge conflict 없음"
echo ""

# =============================================================================
# 3. 머지 확인
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 머지 준비 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Squash and Merge를 진행하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "머지가 취소되었습니다."
    exit 0
fi

# =============================================================================
# 4. 머지 실행
# =============================================================================

info "머지 중..."

gh pr merge --squash --delete-branch

success "머지 완료!"

# =============================================================================
# 5. 로컬 정리
# =============================================================================

info "로컬 브랜치 정리 중..."

# develop으로 이동
git checkout develop 2>/dev/null || git checkout main
git pull

# 로컬 브랜치 삭제 시도
git branch -d "$CURRENT_BRANCH" 2>/dev/null || true

# =============================================================================
# 6. 최종 보고
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "모든 작업 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 PR: #${PR_NUMBER} - ${PR_TITLE}"
echo "✅ 머지: 완료"
echo "🗑️  삭제된 브랜치: ${CURRENT_BRANCH}"
echo ""
echo "다음 단계:"
echo "  ./scripts/start-work.sh <다음이슈번호>"
echo ""
