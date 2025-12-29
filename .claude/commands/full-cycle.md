---
description: 이슈 선택부터 머지까지 전체 워크플로우를 자동으로 실행합니다
---

# /full-cycle - 전체 개발 사이클 자동화

> **참고:** 이 커맨드는 전체 개발 사이클을 자동으로 수행합니다.
> **언어:** 모든 결과는 **한글**로 보고합니다.

---

## 사용법

```
/full-cycle <이슈번호>
```

또는 인자 없이 실행하면 다음 우선순위 이슈를 자동 선택:

```
/full-cycle
```

---

## 전체 워크플로우

```
┌─────────────────────────────────────────────────────────────┐
│                    FULL DEVELOPMENT CYCLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1️⃣  이슈 선택 & 브랜치 생성                                 │
│      └─ /start-work 실행                                    │
│                                                             │
│  2️⃣  기능 구현                                               │
│      ├─ 이슈 요구사항 분석                                   │
│      ├─ Protocol 정의                                       │
│      ├─ Service/ViewModel 구현                              │
│      └─ View 구현                                           │
│                                                             │
│  3️⃣  테스트 작성 & 실행                                      │
│      ├─ Mock 서비스 구현                                    │
│      ├─ ViewModel 단위 테스트                               │
│      └─ 빌드 확인                                           │
│                                                             │
│  4️⃣  커밋 & PR 생성                                         │
│      └─ /commit-push-pr 실행                                │
│                                                             │
│  5️⃣  코드 리뷰 & 머지                                       │
│      └─ /review-merge 실행                                  │
│                                                             │
│  6️⃣  다음 이슈로 전환                                        │
│      └─ /next-issue 실행                                    │
│                                                             │
│  🔄 반복                                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: 이슈 선택 & 브랜치 생성

```bash
# 이슈 번호가 주어지지 않으면 다음 우선순위 이슈 선택
if [ -z "$1" ]; then
  # 현재 열린 이슈 중 가장 낮은 번호 선택
  ISSUE_NUM=$(gh issue list --state open --json number --jq '.[].number' | sort -n | head -1)
else
  ISSUE_NUM=$1
fi

# 이슈 정보 조회
gh issue view $ISSUE_NUM --json number,title,body
```

**실행**: `/start-work $ISSUE_NUM`

---

## Phase 2: 기능 구현

### 2-1. 이슈 요구사항 분석

이슈 본문에서 다음을 추출:
- 구현해야 할 기능 목록
- 필요한 파일/클래스
- 의존성 (이전 이슈 결과물)

### 2-2. 구현 순서

```
Protocol 정의
    ↓
Service 구현 (비즈니스 로직)
    ↓
ViewModel 구현 (UI 로직)
    ↓
View 구현 (SwiftUI)
```

### 2-3. CLAUDE.md 규칙 준수

- MVVM 아키텍처 준수
- Protocol-Oriented 설계
- Force unwrap 금지
- 한글 주석

---

## Phase 3: 테스트 작성 & 실행

### 3-1. Mock 서비스 구현

```swift
// 예시: MockAuthService
class MockAuthService: AuthServiceProtocol {
    var mockUser: User?
    var mockError: Error?

    func getCurrentUser() async throws -> User {
        if let error = mockError { throw error }
        return mockUser ?? User.mock
    }
}
```

### 3-2. ViewModel 단위 테스트

```swift
// 예시: AuthViewModelTests
@MainActor
final class AuthViewModelTests: XCTestCase {
    var sut: AuthViewModel!
    var mockService: MockAuthService!

    override func setUp() {
        mockService = MockAuthService()
        sut = AuthViewModel(authService: mockService)
    }

    func test_login_success() async {
        // Given
        mockService.mockUser = User.mock

        // When
        await sut.login()

        // Then
        XCTAssertTrue(sut.isLoggedIn)
    }
}
```

### 3-3. 빌드 확인

```bash
xcodebuild -scheme damso -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Phase 4: 커밋 & PR 생성

**실행**: `/commit-push-pr`

- Conventional Commit 메시지 자동 생성
- PR 본문 자동 작성
- 이슈 자동 연결

---

## Phase 5: 코드 리뷰 & 머지

**실행**: `/review-merge`

- 코드 리뷰 체크리스트 확인
- Merge conflict 확인
- Squash and Merge 실행

---

## Phase 6: 다음 이슈로 전환

**실행**: `/next-issue`

- 현재 이슈 완료 확인
- 다음 우선순위 이슈 선택
- 새 브랜치 생성

---

## 진행 상황 추적

```
📊 전체 진행률: [████████░░░░░░░░] 47% (8/17)

✅ 완료:
   #8  사용자 모델 정의
   #9  카카오 로그인
   #10 토큰 관리
   ...

🔄 진행 중:
   #15 어르신 홈 화면

⏳ 대기:
   #16 어르신 영상통화
   #17 어르신 설정
   ...
```

---

## 주의사항

1. **한 번에 하나의 이슈만** - 병렬 작업 금지
2. **테스트 필수** - 테스트 없으면 PR 생성 불가
3. **코드 리뷰 통과** - 치명적 이슈 있으면 머지 불가
4. **이슈 순서 준수** - 의존성이 있는 이슈 순서대로 진행

---

## 트러블슈팅

### 빌드 실패 시
```bash
# 클린 빌드
xcodebuild clean -scheme damso
xcodebuild -scheme damso build
```

### Merge Conflict 발생 시
```bash
git fetch origin develop
git merge origin/develop
# 충돌 해결 후
git add .
git commit -m "resolve: merge conflict 해결"
git push
```

### 테스트 실패 시
```bash
# 특정 테스트만 실행
xcodebuild test -scheme damso -only-testing:damsoTests/AuthViewModelTests
```
