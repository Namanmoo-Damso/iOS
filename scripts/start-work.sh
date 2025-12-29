#!/bin/bash

# =============================================================================
# start-work.sh - 이슈 기반 브랜치 생성 스크립트
# 사용법: ./scripts/start-work.sh <ISSUE_NUM> [BRANCH_SUFFIX]
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 이모지 출력 함수
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# 0. 인자 확인
# =============================================================================

if [ -z "$1" ]; then
    echo ""
    info "📋 열린 이슈 목록:"
    echo ""
    gh issue list --state open --json number,title,labels --jq '.[] | "#\(.number)\t\(.title)"'
    echo ""
    echo "사용법: ./scripts/start-work.sh <이슈번호> [브랜치접미사]"
    echo "예시: ./scripts/start-work.sh 8"
    echo "예시: ./scripts/start-work.sh 8 user-model"
    exit 0
fi

ISSUE_NUM=$1
BRANCH_SUFFIX=$2

# =============================================================================
# 1. 현재 상태 확인
# =============================================================================

info "현재 상태 확인 중..."

# 변경사항 확인
if [[ -n $(git status --porcelain) ]]; then
    warning "변경사항이 있습니다. 먼저 커밋하거나 stash 하세요."
    git status --short
    exit 1
fi

# =============================================================================
# 2. 이슈 정보 조회
# =============================================================================

info "이슈 #${ISSUE_NUM} 정보 조회 중..."

ISSUE_INFO=$(gh issue view $ISSUE_NUM --json number,title,body,labels,state 2>/dev/null)

if [ -z "$ISSUE_INFO" ]; then
    error "이슈 #${ISSUE_NUM}을 찾을 수 없습니다."
    exit 1
fi

ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.title')
ISSUE_STATE=$(echo "$ISSUE_INFO" | jq -r '.state')

if [ "$ISSUE_STATE" == "CLOSED" ]; then
    warning "이슈 #${ISSUE_NUM}은 이미 닫혀있습니다."
    read -p "계속 진행하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 이슈 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "번호: #${ISSUE_NUM}"
echo "제목: ${ISSUE_TITLE}"
echo "상태: ${ISSUE_STATE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# 3. 브랜치명 생성
# =============================================================================

# 브랜치 접미사가 주어지지 않으면 이슈 제목에서 생성
if [ -z "$BRANCH_SUFFIX" ]; then
    # 이슈 제목에서 브랜치명 추출 (예: "[Feature] 1. 사용자 모델 정의" → "user-model")
    # 숫자와 점 제거, 특수문자 제거, 공백을 하이픈으로, 소문자로 변환
    BRANCH_SUFFIX=$(echo "$ISSUE_TITLE" | \
        sed 's/\[.*\]//g' | \
        sed 's/[0-9]*\.//g' | \
        sed 's/[^a-zA-Z0-9가-힣 ]//g' | \
        tr ' ' '-' | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/--*/-/g' | \
        sed 's/^-//' | \
        sed 's/-$//' | \
        cut -c1-30)
fi

# 이슈 타입에 따라 브랜치 prefix 결정
if echo "$ISSUE_TITLE" | grep -qi "bug\|fix\|버그\|수정"; then
    BRANCH_PREFIX="fix"
elif echo "$ISSUE_TITLE" | grep -qi "hotfix\|긴급"; then
    BRANCH_PREFIX="hotfix"
else
    BRANCH_PREFIX="feature"
fi

BRANCH_NAME="${BRANCH_PREFIX}/${ISSUE_NUM}-${BRANCH_SUFFIX}"

# =============================================================================
# 4. develop 브랜치에서 분기
# =============================================================================

info "develop 브랜치로 이동 및 최신화..."

git checkout develop
git pull origin develop

# =============================================================================
# 5. 새 브랜치 생성
# =============================================================================

info "브랜치 생성: ${BRANCH_NAME}"

# 브랜치가 이미 존재하는지 확인
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    warning "브랜치 '${BRANCH_NAME}'이 이미 존재합니다."
    read -p "기존 브랜치로 체크아웃하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout "$BRANCH_NAME"
    else
        exit 1
    fi
else
    git checkout -b "$BRANCH_NAME"
fi

# =============================================================================
# 6. 이슈 라벨 업데이트 (선택)
# =============================================================================

# in-progress 라벨 추가 시도 (실패해도 계속 진행)
gh issue edit $ISSUE_NUM --add-label "in-progress" 2>/dev/null || true

# =============================================================================
# 7. 최종 보고
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "작업 준비 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 이슈: #${ISSUE_NUM} - ${ISSUE_TITLE}"
echo "🌿 브랜치: ${BRANCH_NAME}"
echo "🎯 Base: develop"
echo ""
echo "다음 단계:"
echo "  1. 기능 구현"
echo "  2. 테스트 작성"
echo "  3. ./scripts/commit-push-pr.sh 실행"
echo ""
