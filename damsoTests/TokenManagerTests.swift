//
//  TokenManagerTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-29.
//

import XCTest
@testable import damso

@MainActor
final class TokenManagerTests: XCTestCase {

    override func setUp() async throws {
        // 각 테스트 전에 토큰 초기화
        TokenManager.shared.clearTokens()
    }

    override func tearDown() async throws {
        // 테스트 후 정리
        TokenManager.shared.clearTokens()
    }

    // MARK: - Basic Token Operations

    func test_accessToken_saveAndRetrieve() {
        // Given
        let testToken = "test-access-token-12345"

        // When
        TokenManager.shared.accessToken = testToken

        // Then
        XCTAssertEqual(TokenManager.shared.accessToken, testToken)
    }

    func test_refreshToken_saveAndRetrieve() {
        // Given
        let testToken = "test-refresh-token-67890"

        // When
        TokenManager.shared.refreshToken = testToken

        // Then
        XCTAssertEqual(TokenManager.shared.refreshToken, testToken)
    }

    func test_accessToken_delete() {
        // Given
        TokenManager.shared.accessToken = "token-to-delete"
        XCTAssertNotNil(TokenManager.shared.accessToken)

        // When
        TokenManager.shared.accessToken = nil

        // Then
        XCTAssertNil(TokenManager.shared.accessToken)
    }

    func test_refreshToken_delete() {
        // Given
        TokenManager.shared.refreshToken = "token-to-delete"
        XCTAssertNotNil(TokenManager.shared.refreshToken)

        // When
        TokenManager.shared.refreshToken = nil

        // Then
        XCTAssertNil(TokenManager.shared.refreshToken)
    }

    // MARK: - hasTokens

    func test_hasTokens_whenBothExist() {
        // Given
        TokenManager.shared.accessToken = "access"
        TokenManager.shared.refreshToken = "refresh"

        // Then
        XCTAssertTrue(TokenManager.shared.hasTokens)
    }

    func test_hasTokens_whenOnlyAccessExists() {
        // Given
        TokenManager.shared.accessToken = "access"
        TokenManager.shared.refreshToken = nil

        // Then
        XCTAssertFalse(TokenManager.shared.hasTokens)
    }

    func test_hasTokens_whenOnlyRefreshExists() {
        // Given
        TokenManager.shared.accessToken = nil
        TokenManager.shared.refreshToken = "refresh"

        // Then
        XCTAssertFalse(TokenManager.shared.hasTokens)
    }

    func test_hasTokens_whenNoneExist() {
        // Given
        TokenManager.shared.clearTokens()

        // Then
        XCTAssertFalse(TokenManager.shared.hasTokens)
    }

    // MARK: - saveTokens / clearTokens

    func test_saveTokens() {
        // Given
        let accessToken = "new-access-token"
        let refreshToken = "new-refresh-token"

        // When
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)

        // Then
        XCTAssertEqual(TokenManager.shared.accessToken, accessToken)
        XCTAssertEqual(TokenManager.shared.refreshToken, refreshToken)
        XCTAssertTrue(TokenManager.shared.hasTokens)
    }

    func test_clearTokens() {
        // Given
        TokenManager.shared.saveTokens(access: "access", refresh: "refresh")
        XCTAssertTrue(TokenManager.shared.hasTokens)

        // When
        TokenManager.shared.clearTokens()

        // Then
        XCTAssertNil(TokenManager.shared.accessToken)
        XCTAssertNil(TokenManager.shared.refreshToken)
        XCTAssertFalse(TokenManager.shared.hasTokens)
    }

    // MARK: - Token Persistence (Keychain)

    func test_tokens_persistAfterReassignment() {
        // Given: 토큰 저장
        let accessToken = "persistent-access-token"
        let refreshToken = "persistent-refresh-token"
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)

        // When: 다시 읽기
        let retrievedAccess = TokenManager.shared.accessToken
        let retrievedRefresh = TokenManager.shared.refreshToken

        // Then: 같은 값이 반환되어야 함
        XCTAssertEqual(retrievedAccess, accessToken)
        XCTAssertEqual(retrievedRefresh, refreshToken)
    }

    // MARK: - Edge Cases

    func test_saveEmptyToken_handlesGracefully() {
        // Given
        let emptyToken = ""

        // When
        TokenManager.shared.accessToken = emptyToken

        // Then: 빈 토큰도 저장됨
        XCTAssertEqual(TokenManager.shared.accessToken, emptyToken)
    }

    func test_saveUnicodeToken() {
        // Given: 유니코드가 포함된 토큰 (실제로는 발생하지 않지만 테스트)
        let unicodeToken = "token-한글-🔐-test"

        // When
        TokenManager.shared.accessToken = unicodeToken

        // Then
        XCTAssertEqual(TokenManager.shared.accessToken, unicodeToken)
    }

    func test_saveLongToken() {
        // Given: 긴 JWT 토큰
        let longToken = String(repeating: "a", count: 1000)

        // When
        TokenManager.shared.accessToken = longToken

        // Then
        XCTAssertEqual(TokenManager.shared.accessToken, longToken)
    }
}
