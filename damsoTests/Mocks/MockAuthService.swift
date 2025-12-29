//
//  MockAuthService.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-29.
//

import Foundation
@testable import damso

@MainActor
final class MockAuthService: AuthServiceProtocol {

    // MARK: - Configurable Results

    var fetchApiTokenResult: Result<String, Error> = .success("mock-api-token")
    var fetchLiveKitTokenResult: Result<String, Error> = .success("mock-livekit-token")
    var loginWithKakaoResult: Result<AuthResponse, Error>?
    var refreshTokenResult: Result<TokenRefreshResponse, Error>?
    var getMeResult: Result<UserMeResponse, Error>?
    var registerGuardianResult: Result<GuardianRegistrationResponse, Error>?

    // MARK: - Call Tracking

    var fetchApiTokenCallCount = 0
    var fetchLiveKitTokenCallCount = 0
    var loginWithKakaoCallCount = 0
    var refreshTokenCallCount = 0
    var logoutCallCount = 0
    var getMeCallCount = 0
    var registerGuardianCallCount = 0

    var lastWardEmail: String?
    var lastWardPhoneNumber: String?

    var lastRoomName: String?
    var lastKakaoAccessToken: String?
    var lastUserType: UserType?

    // MARK: - State

    private(set) var isLoggedIn: Bool = false

    // MARK: - AuthServiceProtocol

    func fetchApiToken() async throws -> String {
        fetchApiTokenCallCount += 1
        switch fetchApiTokenResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    func fetchLiveKitToken(roomName: String) async throws -> String {
        fetchLiveKitTokenCallCount += 1
        lastRoomName = roomName
        switch fetchLiveKitTokenResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    func loginWithKakao(kakaoAccessToken: String, userType: UserType) async throws -> AuthResponse {
        loginWithKakaoCallCount += 1
        lastKakaoAccessToken = kakaoAccessToken
        lastUserType = userType

        if let result = loginWithKakaoResult {
            switch result {
            case .success(let response):
                isLoggedIn = true
                return response
            case .failure(let error):
                throw error
            }
        }

        // 기본 mock 응답
        let mockResponse = AuthResponse(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600,
            user: UserMeResponse(
                id: "mock-user-id",
                kakaoId: "mock-kakao-id",
                email: "mock@test.com",
                nickname: "MockUser",
                profileImageUrl: nil,
                userType: userType,
                createdAt: Date(),
                guardianInfo: nil,
                wardInfo: nil
            ),
            matchStatus: userType == .ward ? .matched : nil,
            matchMessage: nil
        )
        isLoggedIn = true
        return mockResponse
    }

    func refreshToken() async throws -> TokenRefreshResponse {
        refreshTokenCallCount += 1

        if let result = refreshTokenResult {
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        // 기본 mock 응답
        return TokenRefreshResponse(
            accessToken: "mock-refreshed-access-token",
            refreshToken: "mock-refreshed-refresh-token",
            expiresIn: 3600
        )
    }

    func logout() async {
        logoutCallCount += 1
        isLoggedIn = false
    }

    func getMe() async throws -> UserMeResponse {
        getMeCallCount += 1

        if let result = getMeResult {
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        // 기본 mock 응답
        return UserMeResponse(
            id: "mock-user-id",
            kakaoId: "mock-kakao-id",
            email: "mock@test.com",
            nickname: "MockUser",
            profileImageUrl: nil,
            userType: .guardian,
            createdAt: Date(),
            guardianInfo: nil,
            wardInfo: nil
        )
    }

    func registerGuardian(wardEmail: String, wardPhoneNumber: String) async throws -> GuardianRegistrationResponse {
        registerGuardianCallCount += 1
        lastWardEmail = wardEmail
        lastWardPhoneNumber = wardPhoneNumber

        if let result = registerGuardianResult {
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        // 기본 mock 응답
        return GuardianRegistrationResponse(
            guardianId: "mock-guardian-id",
            userId: "mock-user-id",
            wardEmail: wardEmail,
            wardPhoneNumber: wardPhoneNumber,
            message: "Guardian registered successfully"
        )
    }

    // MARK: - Test Helpers

    func reset() {
        fetchApiTokenCallCount = 0
        fetchLiveKitTokenCallCount = 0
        loginWithKakaoCallCount = 0
        refreshTokenCallCount = 0
        logoutCallCount = 0
        getMeCallCount = 0
        registerGuardianCallCount = 0
        lastRoomName = nil
        lastKakaoAccessToken = nil
        lastUserType = nil
        lastWardEmail = nil
        lastWardPhoneNumber = nil
        isLoggedIn = false

        fetchApiTokenResult = .success("mock-api-token")
        fetchLiveKitTokenResult = .success("mock-livekit-token")
        loginWithKakaoResult = nil
        refreshTokenResult = nil
        getMeResult = nil
        registerGuardianResult = nil
    }
}
