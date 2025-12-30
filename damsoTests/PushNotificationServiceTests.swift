//
//  PushNotificationServiceTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest
@testable import damso

@MainActor
final class PushNotificationServiceTests: XCTestCase {

    override func tearDown() async throws {
        // 테스트 후 토큰 정리
        TokenManager.shared.clearTokens()
    }

    // MARK: - PushError Tests

    func test_pushError_descriptions() {
        XCTAssertEqual(
            PushError.invalidURL.errorDescription,
            "잘못된 URL입니다."
        )
        XCTAssertEqual(
            PushError.serverError.errorDescription,
            "서버 오류가 발생했습니다."
        )
        XCTAssertEqual(
            PushError.unauthorized.errorDescription,
            "인증이 필요합니다."
        )
    }

    // MARK: - PushNotificationService Tests

    func test_registerDeviceToken_withoutToken_skipsRegistration() async throws {
        // Given: 토큰이 없는 상태
        TokenManager.shared.clearTokens()

        // When: 디바이스 토큰 등록 시도
        // 토큰이 없으면 에러 없이 조기 반환됨
        try await PushNotificationService.shared.registerDeviceToken("test-device-token")

        // Then: 에러 없이 완료 (토큰 없으면 조기 반환)
        // 이 테스트는 에러가 발생하지 않음을 확인
    }

    func test_updateNotificationSettings_withoutToken_skipsUpdate() async throws {
        // Given: 토큰이 없는 상태
        TokenManager.shared.clearTokens()

        // When: 알림 설정 업데이트 시도
        // 토큰이 없으면 에러 없이 조기 반환됨
        try await PushNotificationService.shared.updateNotificationSettings(
            callReminder: true,
            callComplete: true,
            healthAlert: true,
            dailySummary: false
        )

        // Then: 에러 없이 완료
    }

    // MARK: - Singleton Tests

    func test_singleton_returnsSameInstance() {
        // Given/When
        let instance1 = PushNotificationService.shared
        let instance2 = PushNotificationService.shared

        // Then: 같은 인스턴스여야 함
        XCTAssertTrue(instance1 === instance2)
    }
}
