//
//  KakaoLinkServiceTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import XCTest
@testable import damso

@MainActor
final class KakaoLinkServiceTests: XCTestCase {

    // MARK: - KakaoLinkError Tests

    func test_kakaoLinkError_descriptions() {
        XCTAssertEqual(
            KakaoLinkError.shareNotAvailable.errorDescription,
            "카카오톡 공유 기능을 사용할 수 없습니다."
        )
        XCTAssertEqual(
            KakaoLinkError.urlError.errorDescription,
            "URL 생성에 실패했습니다."
        )
        XCTAssertEqual(
            KakaoLinkError.templateError("Invalid template").errorDescription,
            "템플릿 오류: Invalid template"
        )
        XCTAssertEqual(
            KakaoLinkError.unknownError("Unknown").errorDescription,
            "알 수 없는 오류: Unknown"
        )
    }

    // MARK: - MockKakaoLinkService Tests

    func test_mockService_shareInviteLink_tracksParameters() async throws {
        // Given
        let mockService = MockKakaoLinkService()
        let guardianId = "guardian-123"
        let guardianName = "홍길동"
        let wardEmail = "elder@test.com"

        // When
        try await mockService.shareInviteLink(
            guardianId: guardianId,
            guardianName: guardianName,
            wardEmail: wardEmail
        )

        // Then
        XCTAssertEqual(mockService.shareInviteLinkCallCount, 1)
        XCTAssertEqual(mockService.lastGuardianId, guardianId)
        XCTAssertEqual(mockService.lastGuardianName, guardianName)
        XCTAssertEqual(mockService.lastWardEmail, wardEmail)
    }

    func test_mockService_shareInviteLink_throwsOnFailure() async {
        // Given
        let mockService = MockKakaoLinkService()
        mockService.shareResult = .failure(KakaoLinkError.shareNotAvailable)

        // When/Then
        do {
            try await mockService.shareInviteLink(
                guardianId: "id",
                guardianName: "name",
                wardEmail: "email"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is KakaoLinkError)
        }
    }

    func test_mockService_isShareAvailable_returnsConfiguredValue() {
        // Given
        let mockService = MockKakaoLinkService()

        // When/Then
        XCTAssertTrue(mockService.isShareAvailable)

        mockService.mockIsShareAvailable = false
        XCTAssertFalse(mockService.isShareAvailable)
    }

    func test_mockService_reset_clearsState() async throws {
        // Given
        let mockService = MockKakaoLinkService()
        try await mockService.shareInviteLink(
            guardianId: "id",
            guardianName: "name",
            wardEmail: "email"
        )
        mockService.mockIsShareAvailable = false

        // When
        mockService.reset()

        // Then
        XCTAssertEqual(mockService.shareInviteLinkCallCount, 0)
        XCTAssertNil(mockService.lastGuardianId)
        XCTAssertNil(mockService.lastGuardianName)
        XCTAssertNil(mockService.lastWardEmail)
        XCTAssertTrue(mockService.isShareAvailable)
    }

    // MARK: - InviteInfo Tests

    func test_inviteInfo_creation() {
        // Given/When
        let info = InviteInfo(
            guardianId: "guardian-123",
            guardianName: "홍길동",
            wardEmail: "elder@test.com"
        )

        // Then
        XCTAssertEqual(info.guardianId, "guardian-123")
        XCTAssertEqual(info.guardianName, "홍길동")
        XCTAssertEqual(info.wardEmail, "elder@test.com")
    }

    func test_inviteInfo_equatable() {
        // Given
        let info1 = InviteInfo(
            guardianId: "id1",
            guardianName: "name1",
            wardEmail: "email1"
        )
        let info2 = InviteInfo(
            guardianId: "id1",
            guardianName: "name1",
            wardEmail: "email1"
        )
        let info3 = InviteInfo(
            guardianId: "id2",
            guardianName: "name1",
            wardEmail: "email1"
        )

        // Then
        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
}
