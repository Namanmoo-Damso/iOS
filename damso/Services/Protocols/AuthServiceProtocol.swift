//
//  AuthServiceProtocol.swift
//  damso
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation

/// 인증 서비스 프로토콜
protocol AuthServiceProtocol {
    /// 익명 API 토큰 발급 (기존 호환성)
    func fetchApiToken() async throws -> String

    /// LiveKit 접속용 토큰 발급
    func fetchLiveKitToken(roomName: String) async throws -> String

    /// 카카오 로그인 + 서버 JWT 발급
    /// - Parameters:
    ///   - kakaoAccessToken: 카카오 access token
    ///   - userType: 사용자 타입 (guardian/ward)
    /// - Returns: 인증 응답 (access token, refresh token, user info)
    func loginWithKakao(kakaoAccessToken: String, userType: UserType) async throws -> AuthResponse

    /// 토큰 갱신
    /// - Returns: 갱신된 토큰 정보
    func refreshToken() async throws -> TokenRefreshResponse

    /// 로그아웃 (토큰 삭제)
    func logout() async

    /// 현재 로그인 상태 확인
    var isLoggedIn: Bool { get }

    /// 현재 사용자 정보 조회
    /// - Returns: 사용자 정보
    func getMe() async throws -> UserMeResponse

    /// 보호자 등록
    /// - Parameters:
    ///   - wardEmail: 피보호자 이메일
    ///   - wardPhoneNumber: 피보호자 전화번호
    /// - Returns: 등록 응답
    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse
}
