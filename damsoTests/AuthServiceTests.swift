//
//  AuthServiceTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-29.
//

import XCTest
@testable import damso

@MainActor
final class AuthServiceTests: XCTestCase {

    // MARK: - AuthError Tests

    func test_authError_descriptions() {
        XCTAssertEqual(
            AuthError.missingAuthToken.errorDescription,
            "인증 토큰이 없습니다."
        )
        XCTAssertEqual(
            AuthError.invalidResponse.errorDescription,
            "잘못된 응답입니다."
        )
        XCTAssertEqual(
            AuthError.unauthorized.errorDescription,
            "인증이 만료되었습니다. 다시 로그인해주세요."
        )
        XCTAssertEqual(
            AuthError.httpStatus(code: 500, body: "").errorDescription,
            "API 요청 실패 (상태 코드: 500)"
        )
        XCTAssertEqual(
            AuthError.httpStatus(code: 500, body: "Server Error").errorDescription,
            "API 요청 실패 (500): Server Error"
        )
        XCTAssertEqual(
            AuthError.networkError("Timeout").errorDescription,
            "네트워크 오류: Timeout"
        )
        XCTAssertEqual(
            AuthError.decodingError("Invalid JSON").errorDescription,
            "디코딩 오류: Invalid JSON"
        )
    }

    // MARK: - TokenError Tests (Legacy)

    func test_tokenError_descriptions() {
        XCTAssertEqual(
            TokenError.missingAuthToken.errorDescription,
            "Missing API auth token. Store it in UserDefaults with key 'authToken'."
        )
        XCTAssertEqual(
            TokenError.invalidResponse.errorDescription,
            "Invalid token response."
        )
        XCTAssertEqual(
            TokenError.missingToken.errorDescription,
            "Token is missing in API response."
        )
        XCTAssertEqual(
            TokenError.networkError("Connection failed").errorDescription,
            "Network Error: Connection failed"
        )
        XCTAssertEqual(
            TokenError.httpStatus(code: 401, body: "").errorDescription,
            "Token API failed with status 401."
        )
        XCTAssertEqual(
            TokenError.httpStatus(code: 401, body: "Unauthorized").errorDescription,
            "Token API failed (401): Unauthorized"
        )
    }

    // MARK: - AuthService State Tests

    func test_authService_isLoggedIn_whenNoTokens() {
        // Given: TokenManager에 토큰이 없는 상태
        TokenManager.shared.clearTokens()

        // When
        let authService = AuthService()

        // Then
        XCTAssertFalse(authService.isLoggedIn)
    }

    func test_authService_isLoggedIn_whenTokensExist() {
        // Given: TokenManager에 토큰이 있는 상태
        TokenManager.shared.saveTokens(access: "test-access", refresh: "test-refresh")

        // When
        let authService = AuthService()

        // Then
        XCTAssertTrue(authService.isLoggedIn)

        // Cleanup
        TokenManager.shared.clearTokens()
    }

    func test_authService_logout_clearsTokens() async {
        // Given
        TokenManager.shared.saveTokens(access: "test-access", refresh: "test-refresh")
        let authService = AuthService()
        XCTAssertTrue(authService.isLoggedIn)

        // When
        await authService.logout()

        // Then
        XCTAssertFalse(authService.isLoggedIn)
        XCTAssertNil(TokenManager.shared.accessToken)
        XCTAssertNil(TokenManager.shared.refreshToken)
    }
}
