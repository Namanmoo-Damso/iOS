//
//  Constants.swift
//  damso
//
//  Created by Claude Code on 2024-12-31.
//

import Foundation

// MARK: - 문자열 상수

/// 앱 전체에서 사용되는 문자열 상수
enum Strings {

    // MARK: - 공통

    enum Common {
        static let appName = "담소"
        static let confirm = "확인"
        static let cancel = "취소"
        static let back = "뒤로"
        static let next = "다음"
        static let done = "완료"
        static let save = "저장"
        static let delete = "삭제"
        static let edit = "수정"
        static let loading = "로딩 중..."
        static let retry = "다시 시도"
        static let error = "오류"
        static let success = "성공"
    }

    // MARK: - 인증

    enum Auth {
        static let welcomeTitle = "담소에 오신 것을 환영합니다!"
        static let selectUserTypeMessage = "시작하기 전에, 본인을 알려주세요"
        static let loginWithKakao = "카카오로 시작하기"
        static let loginFailed = "로그인에 실패했습니다. 다시 시도해주세요."
        static let sessionExpiredTitle = "세션 만료"
        static let sessionExpiredMessage = "로그인 세션이 만료되었습니다.\n다시 로그인해 주세요."
        static let missingToken = "인증 토큰이 없습니다."
        static let logout = "로그아웃"
        static let withdraw = "회원탈퇴"
    }

    // MARK: - 사용자 타입

    enum UserType {
        static let guardian = "보호자"
        static let guardianDescription = "어르신을 돌보는 분"
        static let ward = "어르신"
        static let wardDescription = "케어를 받는 분"
    }

    // MARK: - 보호자 등록

    enum GuardianRegistration {
        static let title = "보호자 등록"
        static let headerTitle = "보호자 정보를 등록해 주세요"
        static let headerSubtitle = "어르신 정보를 입력하시면\n자동으로 연결됩니다"
        static let myInfo = "내 정보"
        static let wardInfo = "어르신 정보"
        static let emailLabel = "이메일"
        static let emailPlaceholder = "어르신의 이메일 주소"
        static let emailInvalid = "올바른 이메일 형식을 입력해 주세요"
        static let phoneLabel = "전화번호"
        static let phonePlaceholder = "어르신의 전화번호"
        static let phoneInvalid = "올바른 전화번호 형식을 입력해 주세요"
        static let registerButton = "가입하기"
        static let registrationComplete = "등록 완료"
        static let registrationCompleteMessage = "보호자 등록이 완료되었습니다.\n카카오톡으로 어르신을 초대해 보세요!"
        static let inviteWard = "어르신 초대하기"
        static let later = "나중에"
        static let kakaoLinked = "카카오 연동"
    }

    // MARK: - 매칭

    enum Matching {
        static let noGuardianTitle = "보호자 정보 없음"
        static let noGuardianMessage = "등록된 보호자 정보가 없습니다.\n보호자에게 먼저 앱에서 회원가입을 요청해주세요."
        static let userTypeMismatchTitle = "사용자 유형 불일치"
        static let userTypeMismatchMessage = "선택한 사용자 유형과 등록된 유형이 다릅니다."
        static let linkedGuardian = "연결된 보호자"
        static let noLinkedGuardian = "연결된 보호자가 없습니다"
    }

    // MARK: - 프로필

    enum Profile {
        static let myInfo = "나의 정보"
        static let basicInfo = "기본 정보"
        static let email = "이메일"
        static let kakaoId = "카카오 ID"
        static let phoneNumber = "전화번호"
    }

    // MARK: - 설정

    enum Settings {
        static let title = "설정"
        static let account = "계정"
        static let notifications = "알림"
        static let privacy = "개인정보"
        static let about = "앱 정보"
        static let version = "버전"
    }

    // MARK: - 네트워크

    enum Network {
        static let noConnection = "인터넷 연결이 없습니다"
        static let connectionRestored = "인터넷 연결이 복원되었습니다"
        static let requestFailed = "요청에 실패했습니다"
        static let serverError = "서버 오류가 발생했습니다"
    }

    // MARK: - 통화

    enum Call {
        static let incoming = "수신 전화"
        static let outgoing = "발신 전화"
        static let connecting = "연결 중..."
        static let connected = "통화 중"
        static let ended = "통화 종료"
        static let missed = "부재중 전화"
        static let accept = "받기"
        static let decline = "거절"
        static let endCall = "통화 종료"
        static let mute = "음소거"
        static let unmute = "음소거 해제"
        static let speaker = "스피커"
        static let camera = "카메라"
    }
}

// MARK: - 숫자 상수

/// 앱 전체에서 사용되는 숫자 상수
enum Numbers {

    // MARK: - 타임아웃

    enum Timeout {
        /// 네트워크 요청 타임아웃 (초)
        static let networkRequest: TimeInterval = 15
        /// 토큰 갱신 타임아웃 (초)
        static let tokenRefresh: TimeInterval = 10
        /// LiveKit 연결 타임아웃 (초)
        static let liveKitConnection: TimeInterval = 30
    }

    // MARK: - 통화 설정

    enum Call {
        /// 기본 주간 통화 횟수
        static let defaultWeeklyCount = 3
        /// 기본 통화 시간 (분)
        static let defaultDurationMinutes = 15
        /// 최대 통화 시간 (분)
        static let maxDurationMinutes = 60
    }

    // MARK: - UI

    enum UI {
        /// 기본 코너 반경
        static let defaultCornerRadius: CGFloat = 12
        /// 작은 코너 반경
        static let smallCornerRadius: CGFloat = 8
        /// 큰 코너 반경
        static let largeCornerRadius: CGFloat = 16
        /// 기본 패딩
        static let defaultPadding: CGFloat = 16
        /// 작은 패딩
        static let smallPadding: CGFloat = 8
        /// 큰 패딩
        static let largePadding: CGFloat = 24
        /// 프로필 이미지 크기 (작음)
        static let profileImageSmall: CGFloat = 44
        /// 프로필 이미지 크기 (중간)
        static let profileImageMedium: CGFloat = 60
        /// 프로필 이미지 크기 (큼)
        static let profileImageLarge: CGFloat = 80
        /// 버튼 높이
        static let buttonHeight: CGFloat = 50
    }

    // MARK: - 애니메이션

    enum Animation {
        /// 기본 애니메이션 지속 시간
        static let defaultDuration: Double = 0.3
        /// 빠른 애니메이션 지속 시간
        static let fastDuration: Double = 0.15
        /// 느린 애니메이션 지속 시간
        static let slowDuration: Double = 0.5
    }

    // MARK: - 검증

    enum Validation {
        /// 최소 전화번호 자릿수
        static let minPhoneDigits = 10
        /// 최대 전화번호 자릿수
        static let maxPhoneDigits = 11
    }
}

// MARK: - UserDefaults 키

/// UserDefaults 저장 키
enum UserDefaultsKeys {
    static let selectedServerDomain = "selectedServerDomain"
    static let pendingLoginUserType = "pendingLoginUserType"
    static let kakaoUserId = "kakao_user_id"
    static let userIdentity = "user_identity"
    static let cachedApnsToken = "cached_apns_token"
    static let cachedVoipToken = "cached_voip_token"
    static let legacyAuthToken = "authToken"
}

// MARK: - Keychain 키

/// Keychain 저장 키
enum KeychainKeys {
    static let accessToken = "accessToken"
    static let refreshToken = "refreshToken"
}
