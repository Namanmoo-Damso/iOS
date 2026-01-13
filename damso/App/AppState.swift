//
//  AppState.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI
import Combine

/// 앱 전역 상태 관리
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// 인증 상태
    @Published private(set) var isAuthenticated = false

    /// 로딩 상태 (앱 시작 시 토큰 검증 중)
    @Published private(set) var isLoading = true

    /// 세션 만료 Alert 표시 여부
    @Published var showSessionExpiredAlert = false

    /// 현재 사용자 정보
    @Published private(set) var currentUser: UserMeResponse?

    /// 에러 메시지
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let authService: AuthService

    // MARK: - Initialization

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    // MARK: - Public Methods

    /// 앱 시작 시 인증 상태 확인
    func checkAuthStatus() async {
        isLoading = true
        errorMessage = nil

        // 토큰이 없으면 미인증 상태
        guard TokenManager.shared.hasTokens else {
            debugLog("No tokens found, user is not authenticated")
            isAuthenticated = false
            isLoading = false
            return
        }

        debugLog("Tokens found, validating with server...")

        do {
            // 서버에 토큰 유효성 확인
            let userInfo = try await authService.getMe()
            currentUser = userInfo
            isAuthenticated = true
            debugLog("Token valid, user authenticated: \(userInfo.nickname ?? "")")
        } catch let error as AuthError {
            await handleAuthError(error)
        } catch {
            debugLog("Unexpected error during auth check: \(error)")
            // 네트워크 오류 시 인증 실패로 처리 (유효하지 않은 상태로 진입 방지)
            isAuthenticated = false
        }

        isLoading = false
    }

    /// 로그인 성공 처리
    func didLogin(user: UserMeResponse) {
        currentUser = user
        isAuthenticated = true
        debugLog("User logged in: \(user.nickname ?? "")")
    }

    /// 현재 사용자 정보 새로고침
    func refreshCurrentUser() async throws {
        debugLog("Refreshing current user info...")
        let userInfo = try await authService.getMe()
        currentUser = userInfo
        debugLog("User info refreshed: \(userInfo.nickname ?? "")")
    }

    /// 로그아웃
    func logout() async {
        await authService.logout()
        await KakaoAuthService.shared.logout()
        currentUser = nil
        isAuthenticated = false
        debugLog("User logged out")
    }

    /// 회원탈퇴
    func withdraw() async throws {
        debugLog("Withdrawing user...")

        do {
            // 서버에 탈퇴 요청
            try await authService.deleteUser()

            // 카카오 연결 끊기
            await KakaoAuthService.shared.unlink()

            // 로컬 상태 정리
            TokenManager.shared.clearTokens()
            currentUser = nil
            isAuthenticated = false

            debugLog("User withdrawn successfully")
        } catch {
            debugLog("Withdraw failed: \(error)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func handleAuthError(_ error: AuthError) async {
        switch error {
        case .unauthorized:
            debugLog("Token expired, attempting refresh...")
            await attemptTokenRefresh()
        case .missingAuthToken:
            debugLog("No auth token")
            isAuthenticated = false
        default:
            debugLog("Auth error: \(error.localizedDescription)")
            // 기타 에러는 일단 로그인 상태 유지 (네트워크 문제일 수 있음)
            isAuthenticated = TokenManager.shared.hasTokens
        }
    }

    private func attemptTokenRefresh() async {
        do {
            _ = try await authService.refreshToken()
            // 새 토큰으로 다시 사용자 정보 조회
            let userInfo = try await authService.getMe()
            currentUser = userInfo
            isAuthenticated = true
            debugLog("Token refreshed successfully")
        } catch {
            debugLog("Token refresh failed: \(error)")
            // 리프레시 실패 - 세션 만료
            TokenManager.shared.clearTokens()
            currentUser = nil
            isAuthenticated = false
            showSessionExpiredAlert = true
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AppState] \(message)")
        #endif
    }
}
