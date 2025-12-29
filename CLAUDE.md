# CLAUDE.md - Damso iOS Project Constitution

> 이 문서는 AI 모델이 iOS 프로젝트 컨텍스트를 이해하고, 코드 품질을 일관되게 유지하기 위한 **프로젝트 헌법(Constitution)**입니다.

**버전:** 1.0
**최종 수정:** 2025년 12월 29일
**문서 상태:** 활성

---

<project_info>
<description>
Damso - 보호자/어르신 간 실시간 영상통화 및 케어 서비스 iOS 앱
LiveKit 기반 WebRTC 영상통화, 카카오 소셜 로그인, 푸시 알림 지원
보호자(Guardian)와 어르신(Ward) 2가지 사용자 타입 지원
</description>

<tech_stack>
- **Language**: Swift 5.9+
- **Platform**: iOS 15.0+
- **Architecture**: MVVM + Protocol-Oriented
- **UI Framework**: SwiftUI
- **Realtime**: LiveKit SDK (WebRTC 영상통화)
- **Auth**: Kakao SDK (소셜 로그인)
- **Storage**: Keychain (토큰 저장), UserDefaults (설정)
- **Network**: URLSession, async/await
- **Push**: APNs (Apple Push Notification service)
- **Location**: CoreLocation (백그라운드 위치 추적)
- **DI**: Manual Dependency Injection (DependencyContainer)
- **Build**: Xcode 15+, Swift Package Manager
</tech_stack>

<core_entities>
<!-- 사용자 시스템 -->
- **User**: 공통 사용자 정보 (kakaoId, email, nickname, profileImageUrl)
- **Guardian**: 보호자 (wardEmail, wardPhoneNumber로 어르신 연결)
- **Ward**: 어르신 (guardianId로 보호자와 연결, 자동 매칭)
- **UserType**: enum (guardian, ward) - 사용자 타입 구분

<!-- 핵심 서비스 -->
- **AuthService**: 인증 상태 관리
- **KakaoAuthService**: 카카오 로그인 처리
- **LiveKitService**: 영상통화 연결
- **CallManager**: 통화 상태 관리
- **NetworkMonitor**: 네트워크 상태 감시
</core_entities>

<user_flow>
<!-- 보호자 플로우 -->
1. StartView → 서버 선택
2. KakaoLoginView → 카카오 로그인
3. UserTypeSelectionView → "보호자" 선택
4. GuardianRegistrationView → 어르신 이메일/전화번호 입력
5. GuardianTabView (Home, Call, Settings)

<!-- 어르신 플로우 -->
1. StartView → 서버 선택
2. KakaoLoginView → 카카오 로그인
3. 자동 매칭 (보호자가 등록한 email과 일치 시)
4. WardTabView (Home, Call, Settings)
</user_flow>
</project_info>

---

<coding_rules>
<swift>
- MUST: Swift 5.9+ 기능 활용 (async/await, Actors, Observation)
- MUST: 프로토콜 지향 설계 - 모든 서비스는 Protocol 정의 후 구현
- MUST: @MainActor 적절히 사용 (UI 업데이트 관련 코드)
- MUST: 불변성 선호 - `let` 우선, 필요시에만 `var`
- MUST: 옵셔널 안전하게 처리 - guard let, if let, nil coalescing
- SHOULD: Result 타입 또는 async throws 활용
- MUST NOT: Force unwrap (`!`) 사용 금지 (테스트 제외)
- MUST NOT: implicitly unwrapped optional (`!`) 프로퍼티 선언 금지
- MUST NOT: 하드코딩된 문자열 (Localizable.strings 또는 상수 정의)
</swift>

<swiftui>
- MUST: View는 작고 재사용 가능하게 분리
- MUST: @StateObject는 View 생성 시점에만, @ObservedObject는 주입받을 때
- MUST: EnvironmentObject로 전역 상태 공유 (최소화)
- SHOULD: PreviewProvider 제공 (UI 미리보기)
- SHOULD: ViewModifier로 스타일 재사용
- MUST NOT: View에서 비즈니스 로직 구현 (ViewModel로 분리)
- MUST NOT: onAppear에서 무거운 작업 (Task로 비동기 처리)
</swiftui>

<mvvm>
- MUST: View → ViewModel → Service 레이어 분리
- MUST: ViewModel은 @MainActor class, ObservableObject 준수
- MUST: Service는 Protocol 정의 후 구현체 작성
- MUST: DependencyContainer로 의존성 주입
- SHOULD: ViewModel 테스트 작성 (Mock Service 사용)
- MUST NOT: View에서 Service 직접 호출
- MUST NOT: ViewModel 간 직접 참조 (Coordinator 또는 NotificationCenter 사용)
</mvvm>

<networking>
- MUST: async/await 사용 (Completion handler 지양)
- MUST: Codable로 JSON 파싱
- MUST: 에러 처리 - NetworkError enum 정의
- MUST: 토큰은 Keychain에 저장 (UserDefaults 금지)
- SHOULD: URLSession 기반 커스텀 NetworkClient 사용
- SHOULD: Request/Response DTO 분리
- MUST NOT: 하드코딩된 URL (AppConfig에서 관리)
- MUST NOT: API 키/시크릿 소스코드에 포함
</networking>

<keychain>
- MUST: KeychainAccess 라이브러리 사용
- MUST: accessToken, refreshToken 별도 저장
- MUST: 앱 삭제 시 Keychain 정리 고려
- SHOULD: TokenManager 싱글톤으로 관리
</keychain>

<livekit>
- MUST: LiveKitService 프로토콜 통해 접근
- MUST: Room 연결/해제 라이프사이클 관리
- MUST: 오디오/비디오 권한 사전 확인
- SHOULD: 재연결 로직 구현 (네트워크 불안정 대응)
- MUST NOT: Room 객체 직접 노출 (Service로 래핑)
</livekit>

<testing>
- MUST: ViewModel 단위 테스트 필수
- MUST: Mock Protocol 구현으로 테스트 격리
- SHOULD: UI 테스트 (XCUITest) 주요 플로우
- SHOULD: 비동기 테스트는 XCTestExpectation 사용
- MUST NOT: 실제 네트워크 호출 (Mock 사용)
- MUST NOT: 테스트 간 상태 공유
</testing>

<naming>
- 파일: PascalCase (예: `UserTypeSelectionView.swift`)
- 클래스/구조체: PascalCase (예: `GuardianRegistrationViewModel`)
- 프로토콜: ~Protocol 접미사 (예: `AuthServiceProtocol`)
- 변수/함수: camelCase (예: `fetchUserProfile()`)
- 상수: camelCase 또는 UPPER_SNAKE_CASE (예: `defaultTimeout`)
- Enum case: camelCase (예: `case guardian`, `case ward`)
- View: ~View 접미사 (예: `ContentView`)
- ViewModel: ~ViewModel 접미사 (예: `LiveKitViewModel`)
</naming>
</coding_rules>

---

<restrictions>
<!-- 절대 금지 사항 -->

🔴 **MUST NOT (절대 금지)**:
- Force unwrap (`!`) 프로덕션 코드에서 사용
- API 키/시크릿 소스코드에 하드코딩
- View에서 비즈니스 로직 구현
- UserDefaults에 민감 정보 저장 (토큰 등)
- main 브랜치에 직접 push
- develop 브랜치에 직접 push
- PR 없이 main/develop에 머지
- 테스트 없는 ViewModel 커밋
- 한글 주석 외 영어 주석 (주석은 한글로)

⚠️ **SHOULD NOT (지양)**:
- 500줄 이상의 단일 파일
- 3개 이상 중첩된 클로저
- Combine 과도한 사용 (async/await 우선)
- 싱글톤 남용 (DI 우선)
- print() 디버깅 (Logger 사용)
- Any 타입 사용
</restrictions>

---

<branch_strategy>
<!-- 3-Layer 브랜치 전략 -->

| 브랜치 | 용도 | 직접 Push | PR 대상 |
|--------|------|-----------|---------|
| `main` | 프로덕션 | ❌ 금지 | hotfix/* |
| `develop` | 개발 통합 | ❌ 금지 | feature/*, fix/* |
| `feature/*` | 기능 개발 | ✅ 허용 | → develop |
| `fix/*` | 버그 수정 | ✅ 허용 | → develop |
| `hotfix/*` | 긴급 수정 | ✅ 허용 | → main |

**브랜치 네이밍**:
- `feature/{issue-number}-{description}` (예: `feature/8-user-model`)
- `fix/{issue-number}-{description}` (예: `fix/15-crash-on-call`)
- `hotfix/{description}` (예: `hotfix/auth-token-expired`)
</branch_strategy>

---

<commit_convention>
<!-- Conventional Commits (한글 메시지) -->

```
feat: 새 기능 추가
fix: 버그 수정
docs: 문서 변경
style: 코드 포맷팅 (동작 변화 X)
refactor: 리팩토링 (동작 변화 X)
perf: 성능 개선
test: 테스트 추가/수정
chore: 빌드, 설정 변경
ci: CI/CD 설정 변경
```

**예시**:
- `feat(auth): 카카오 로그인 연동 구현`
- `fix(call): 영상통화 재연결 시 크래시 수정`
- `refactor(model): User 모델 Guardian/Ward 분리`
- `test(auth): TokenManager 단위 테스트 추가`
</commit_convention>

---

<file_structure>
<!-- 프로젝트 구조 -->

```
damso/
├── App/                           # 앱 진입점
│   ├── damsoApp.swift             # @main App
│   ├── AppDelegate.swift          # UIApplicationDelegate
│   ├── AppDelegate+VoIP.swift     # VoIP 푸시 처리
│   └── AppDelegate+Notifications.swift  # APNs 처리
├── Core/                          # 핵심 설정
│   ├── AppConfig.swift            # 환경 설정 (URL, 상수)
│   └── DependencyContainer.swift  # DI 컨테이너
├── Models/                        # 데이터 모델 ⭐ 생성 필요
│   ├── User.swift                 # 공통 사용자
│   ├── Guardian.swift             # 보호자
│   ├── Ward.swift                 # 어르신
│   └── UserType.swift             # 사용자 타입 enum
├── Services/                      # 서비스 레이어
│   ├── Protocols/                 # 프로토콜 정의
│   │   ├── AuthServiceProtocol.swift
│   │   ├── LiveKitServiceProtocol.swift
│   │   └── NetworkMonitorProtocol.swift
│   ├── AuthService.swift          # 인증 서비스
│   ├── KakaoAuthService.swift     # 카카오 로그인
│   ├── LiveKitService.swift       # 영상통화 서비스
│   ├── CallManager.swift          # 통화 관리
│   ├── NetworkMonitor.swift       # 네트워크 상태
│   └── TokenManager.swift         # 토큰 관리 ⭐ 생성 필요
├── ViewModels/                    # MVVM 뷰모델
│   ├── LiveKitViewModel.swift     # 영상통화 뷰모델
│   ├── AuthViewModel.swift        # 인증 뷰모델 ⭐ 생성 필요
│   └── GuardianViewModel.swift    # 보호자 뷰모델 ⭐ 생성 필요
├── Views/                         # SwiftUI 뷰
│   ├── StartView.swift            # 시작 화면
│   ├── ContentView.swift          # 메인 컨테이너
│   ├── KakaoLoginView.swift       # 카카오 로그인
│   ├── LiveKitRoomView.swift      # 영상통화 룸
│   ├── CallUI/                    # 통화 UI 컴포넌트
│   │   ├── FullScreenCallView.swift
│   │   ├── CallTopBar.swift
│   │   ├── CallControlBar.swift
│   │   └── LocalVideoPIP.swift
│   └── Components/                # 재사용 컴포넌트
│       └── NetworkStatusIndicator.swift
├── Utilities/                     # 유틸리티
│   └── DeviceCapability.swift
├── Resources/                     # 리소스
│   └── Assets.xcassets
└── Tests/                         # 테스트 ⭐ 구성 필요
    ├── ViewModelTests/
    └── ServiceTests/
```
</file_structure>

---

<issue_tracker>
<!-- GitHub 이슈 연동 -->

**이슈 순서 (구현 우선순위)**:
1. #8: 사용자 모델 정의 (User, Guardian, Ward)
2. #9: 카카오 로그인 + 서버 JWT 발급
3. #10: Keychain 토큰 관리 + 자동 로그인
4. #11: 사용자 타입 선택 화면
5. #12: 보호자 회원가입 폼
6. #13: 카카오링크 초대 공유
7. #14: 어르신 자동 매칭 + 메인 이동
8. #15: 어르신 홈 화면
9. #16: 어르신 영상통화 연결
10. #17: 어르신 설정 화면
11. #18: 보호자 대시보드 (홈)
12. #19: 보호자 분석 보고서
13. #20: 보호자 설정 (피보호자 관리)
14. #21: 로그아웃/회원탈퇴 + 웹훅
15. #22: 푸시 알림 (APNs)
16. #23: 실시간 위치정보 전송
17. #24: 비상 버튼 기능

**브랜치 생성 규칙**:
- `feature/{issue-number}-{short-desc}`
- 예: `feature/8-user-model`
</issue_tracker>

---

<workflow_protocol>
<!-- AI 모델 작업 프로토콜 -->

1. **이슈 선택 및 브랜치 생성**
   ```bash
   # start-work 스크립트 사용
   ./scripts/start-work.sh <issue-number>
   ```

2. **코드 분석 및 계획**
   - 관련 기존 코드 확인
   - 영향 받는 파일 파악
   - 구현 계획 수립

3. **구현**
   - Protocol 먼저 정의
   - 구현체 작성
   - ViewModel 연결
   - View 구현

4. **테스트 작성**
   - Mock 서비스 구현
   - ViewModel 단위 테스트
   - 빌드 확인

5. **커밋 및 PR**
   ```bash
   # commit-push-pr 스크립트 사용
   ./scripts/commit-push-pr.sh
   ```

6. **코드 리뷰 및 머지**
   - PR 리뷰 자동화
   - Merge conflict 확인
   - develop으로 머지
</workflow_protocol>

---

<commands>
<!-- 자주 사용하는 명령어 -->

| 명령어 | 설명 |
|--------|------|
| `xcodebuild -scheme damso build` | 빌드 |
| `xcodebuild test -scheme damso -destination 'platform=iOS Simulator,name=iPhone 16'` | 테스트 |
| `swift build` | Swift Package 빌드 |
| `./scripts/start-work.sh <issue>` | 이슈 작업 시작 |
| `./scripts/commit-push-pr.sh` | 커밋, 푸시, PR |
</commands>

---

<api_endpoints>
<!-- 백엔드 API (ops_backend) -->

**Base URL**: `AppConfig.current.apiBaseUrl`

| Endpoint | Method | 설명 |
|----------|--------|------|
| `/auth/kakao` | POST | 카카오 로그인 → JWT 발급 |
| `/auth/refresh` | POST | JWT 토큰 갱신 |
| `/users/me` | GET | 내 정보 조회 |
| `/guardians` | POST | 보호자 등록 |
| `/wards/match` | POST | 어르신 자동 매칭 |
| `/rtc/token` | POST | LiveKit 토큰 발급 |
| `/devices/register` | POST | 기기 등록 (푸시) |
| `/push/*` | - | 푸시 알림 API |
| `/calls/*` | - | 통화 관련 API |
</api_endpoints>

---

<ai_code_review>
<!-- 코드 리뷰 기준 -->

## AI 코드 리뷰어 페르소나

당신은 **Damso iOS 프로젝트의 시니어 iOS 개발자**입니다.

### 리뷰 우선순위

1. **치명적** (🔴): 크래시, 메모리 누수, 보안 취약점, 강제 언래핑
2. **경고** (⚠️): 아키텍처 위반, 성능 이슈, 테스트 누락
3. **제안** (💡): 코드 스타일, 리팩토링 기회

### 🔴 치명적 (즉시 수정)
- Force unwrap (`!`) 사용
- 메모리 순환 참조 (strong reference cycle)
- 민감 정보 하드코딩
- Main thread 블로킹
- 권한 요청 없이 카메라/마이크 접근

### ⚠️ 경고 (권장 수정)
- View에서 비즈니스 로직
- 테스트 없는 ViewModel
- 과도한 중첩 클로저
- 500줄 이상 파일
- Protocol 없이 Service 직접 사용

### 💡 제안 (선택)
- 더 나은 Swift 패턴 제안
- 코드 정리 기회
- 성능 최적화 포인트
</ai_code_review>

---

<request_guidelines>
<!-- 요청 시 주의사항 -->

1. 새 기능은 기존 아키텍처(MVVM) 패턴 준수
2. Protocol 먼저 정의 후 구현체 작성
3. 모든 ViewModel에 테스트 코드 필수
4. 커밋 메시지는 한글로 작성
5. PR 본문에 변경사항 요약 필수
6. 이슈 번호 연결 필수 (`Closes #8`)
</request_guidelines>

---

## 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2025.12.29 | 최초 작성 - iOS 프로젝트 전용 Constitution |
