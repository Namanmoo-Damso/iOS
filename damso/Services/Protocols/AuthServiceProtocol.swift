//
//  AuthServiceProtocol.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

// MARK: - 분리된 프로토콜 (ISP 원칙)

/// 인증 전용 프로토콜
protocol AuthenticationProtocol {
    /// 카카오 로그인 + 서버 JWT 발급
    func loginWithKakao(kakaoAccessToken: String, kakaoUserInfo: KakaoUserInfo?, userType: UserType?) async throws -> AuthResponse

    /// 토큰 갱신
    func refreshToken() async throws -> TokenRefreshResponse

    /// 로그아웃 (토큰 삭제)
    func logout() async

    /// 현재 로그인 상태 확인
    var isLoggedIn: Bool { get }
}

/// 사용자 정보 프로토콜
protocol UserInfoProtocol {
    /// 현재 사용자 정보 조회
    func getMe() async throws -> UserMeResponse

    /// 회원탈퇴
    func deleteUser() async throws
}

/// 등록 프로토콜
protocol RegistrationProtocol {
    /// 보호자 등록 (기존 - 호환성 유지)
    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse

    /// 보호자 등록 (확장 - 어르신 상세 정보 포함)
    func registerGuardian(
        wardEmail: String,
        wardPhoneNumber: String,
        wardBasicInfo: WardBasicInfo?,
        aiCareInfo: AICarInfo?,
        callSchedule: AICallSchedule?
    ) async throws -> GuardianRegistrationResponse
}

/// RTC 토큰 프로토콜
protocol RTCTokenProtocol {
    /// LiveKit 접속용 토큰 발급
    func fetchLiveKitToken(roomName: String) async throws -> String
}

// MARK: - 통합 프로토콜 (기존 호환성 유지)

/// 인증 서비스 통합 프로토콜
/// 개별 프로토콜들의 합성으로 정의됨
protocol AuthServiceProtocol: AuthenticationProtocol, UserInfoProtocol, RegistrationProtocol, RTCTokenProtocol {}
