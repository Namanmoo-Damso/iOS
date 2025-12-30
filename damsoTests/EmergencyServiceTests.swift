//
//  EmergencyServiceTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest
@testable import damso

@MainActor
final class EmergencyServiceTests: XCTestCase {

    // MARK: - EmergencyType Tests

    func test_emergencyType_rawValues() {
        XCTAssertEqual(EmergencyType.manual.rawValue, "manual")
        XCTAssertEqual(EmergencyType.fall.rawValue, "fall")
        XCTAssertEqual(EmergencyType.health.rawValue, "health")
        XCTAssertEqual(EmergencyType.other.rawValue, "other")
    }

    func test_emergencyType_defaultMessages() {
        XCTAssertEqual(EmergencyType.manual.defaultMessage, "비상 버튼이 눌렸습니다")
        XCTAssertEqual(EmergencyType.fall.defaultMessage, "낙상이 감지되었습니다")
        XCTAssertEqual(EmergencyType.health.defaultMessage, "건강 이상이 감지되었습니다")
        XCTAssertEqual(EmergencyType.other.defaultMessage, "긴급 상황이 발생했습니다")
    }

    // MARK: - EmergencyError Tests

    func test_emergencyError_descriptions() {
        XCTAssertEqual(
            EmergencyError.invalidURL.errorDescription,
            "잘못된 URL입니다."
        )
        XCTAssertEqual(
            EmergencyError.serverError.errorDescription,
            "서버 오류가 발생했습니다."
        )
        XCTAssertEqual(
            EmergencyError.unauthorized.errorDescription,
            "인증이 필요합니다."
        )
    }

    // MARK: - EmergencyService Tests

    func test_triggerEmergency_failsWithoutToken() async {
        // Given: TokenManager에 토큰이 없는 상태
        TokenManager.shared.clearTokens()

        // When/Then
        do {
            try await EmergencyService.shared.triggerEmergency()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is EmergencyError)
            if let emergencyError = error as? EmergencyError {
                XCTAssertEqual(emergencyError, EmergencyError.unauthorized)
            }
        }
    }

    func test_emergencyType_allCasesExist() {
        let types: [EmergencyType] = [.manual, .fall, .health, .other]
        XCTAssertEqual(types.count, 4)
    }
}
