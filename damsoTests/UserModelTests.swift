//
//  UserModelTests.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-29.
//

import XCTest
@testable import damso

@MainActor
final class UserModelTests: XCTestCase {

    // MARK: - UserType Tests

    func test_userType_displayName() {
        XCTAssertEqual(UserType.guardian.displayName, "보호자")
        XCTAssertEqual(UserType.ward.displayName, "어르신")
    }

    func test_userType_codable() throws {
        // Given
        let guardian = UserType.guardian
        let ward = UserType.ward

        // When
        let encodedGuardian = try JSONEncoder().encode(guardian)
        let encodedWard = try JSONEncoder().encode(ward)

        // Then
        XCTAssertEqual(String(data: encodedGuardian, encoding: .utf8), "\"guardian\"")
        XCTAssertEqual(String(data: encodedWard, encoding: .utf8), "\"ward\"")
    }

    // MARK: - User Tests

    func test_user_decoding() throws {
        // Given
        let json = """
        {
            "id": "user-uuid-001",
            "kakao_id": "1234567890",
            "email": "test@example.com",
            "nickname": "테스트사용자",
            "profile_image_url": "https://example.com/image.jpg",
            "user_type": "guardian",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        // When
        let user = try JSONDecoder.apiDecoder.decode(User.self, from: json)

        // Then
        XCTAssertEqual(user.id, "user-uuid-001")
        XCTAssertEqual(user.kakaoId, "1234567890")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.nickname, "테스트사용자")
        XCTAssertEqual(user.profileImageUrl, "https://example.com/image.jpg")
        XCTAssertEqual(user.userType, .guardian)
    }

    func test_user_decoding_withNullProfileImage() throws {
        // Given
        let json = """
        {
            "id": "user-uuid-002",
            "kakao_id": "0987654321",
            "email": "ward@example.com",
            "nickname": "어르신",
            "profile_image_url": null,
            "user_type": "ward",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        // When
        let user = try JSONDecoder.apiDecoder.decode(User.self, from: json)

        // Then
        XCTAssertEqual(user.id, "user-uuid-002")
        XCTAssertEqual(user.userType, .ward)
        XCTAssertNil(user.profileImageUrl)
    }

    func test_user_equatable() {
        // Given
        let user1 = User(
            id: "same-id",
            kakaoId: "123",
            email: "a@test.com",
            nickname: "A",
            profileImageUrl: nil,
            userType: .guardian,
            createdAt: Date()
        )
        let user2 = User(
            id: "same-id",
            kakaoId: "456",
            email: "b@test.com",
            nickname: "B",
            profileImageUrl: nil,
            userType: .ward,
            createdAt: Date()
        )
        let user3 = User(
            id: "different-id",
            kakaoId: "123",
            email: "a@test.com",
            nickname: "A",
            profileImageUrl: nil,
            userType: .guardian,
            createdAt: Date()
        )

        // Then
        XCTAssertEqual(user1, user2)  // 같은 ID면 같은 사용자
        XCTAssertNotEqual(user1, user3)  // 다른 ID면 다른 사용자
    }

    // MARK: - Guardian Tests

    func test_guardian_isLinkedToWard() {
        // Given
        let guardianWithoutWard = Guardian(
            id: "guardian-001",
            user: User.mockGuardian,
            wardEmail: "ward@test.com",
            wardPhoneNumber: "010-1234-5678",
            linkedWard: nil
        )

        // Then
        XCTAssertFalse(guardianWithoutWard.isLinkedToWard)
    }

    // MARK: - Ward Tests

    func test_ward_linkType() {
        // Given
        let unlinkedWard = Ward(
            id: "ward-001",
            user: User.mockWard,
            phoneNumber: "010-1234-5678",
            linkedGuardian: nil,
            linkedOrganization: nil
        )

        // Then
        XCTAssertEqual(unlinkedWard.linkType, .none)
        XCTAssertFalse(unlinkedWard.isLinked)
    }

    // MARK: - APIResponse Tests

    func test_userMeResponse_guardianType() throws {
        // Given
        let json = """
        {
            "id": "user-uuid-001",
            "kakao_id": "1234567890",
            "email": "guardian@example.com",
            "nickname": "보호자",
            "profile_image_url": null,
            "user_type": "guardian",
            "created_at": "2024-01-01T00:00:00Z",
            "guardian_info": {
                "ward_email": "ward@example.com",
                "ward_phone_number": "010-1234-5678",
                "linked_ward": null
            },
            "ward_info": null
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder.apiDecoder.decode(UserMeResponse.self, from: json)

        // Then
        XCTAssertEqual(response.userType, .guardian)
        XCTAssertNotNil(response.guardianInfo)
        XCTAssertNil(response.wardInfo)
        XCTAssertEqual(response.guardianInfo?.wardEmail, "ward@example.com")
    }

    func test_userMeResponse_wardType() throws {
        // Given
        let json = """
        {
            "id": "user-uuid-002",
            "kakao_id": "0987654321",
            "email": "ward@example.com",
            "nickname": "어르신",
            "profile_image_url": null,
            "user_type": "ward",
            "created_at": "2024-01-01T00:00:00Z",
            "guardian_info": null,
            "ward_info": {
                "phone_number": "010-9876-5432",
                "linked_guardian": {
                    "id": "guardian-001",
                    "user_id": "user-uuid-001",
                    "nickname": "보호자",
                    "profile_image_url": null
                },
                "linked_organization": null
            }
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder.apiDecoder.decode(UserMeResponse.self, from: json)

        // Then
        XCTAssertEqual(response.userType, .ward)
        XCTAssertNil(response.guardianInfo)
        XCTAssertNotNil(response.wardInfo)
        XCTAssertNotNil(response.wardInfo?.linkedGuardian)
        XCTAssertEqual(response.wardInfo?.linkedGuardian?.nickname, "보호자")
    }

    func test_authResponse_decoding() throws {
        // Given
        let json = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            "expires_in": 3600,
            "user": {
                "id": "user-uuid-001",
                "kakao_id": "1234567890",
                "email": "test@example.com",
                "nickname": "테스트",
                "profile_image_url": null,
                "user_type": "guardian",
                "created_at": "2024-01-01T00:00:00Z",
                "guardian_info": null,
                "ward_info": null
            }
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: json)

        // Then
        XCTAssertFalse(response.accessToken.isEmpty)
        XCTAssertFalse(response.refreshToken.isEmpty)
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertEqual(response.user.nickname, "테스트")
        XCTAssertNil(response.matchStatus)
        XCTAssertNil(response.matchMessage)
    }

    // MARK: - MatchStatus Tests

    func test_matchStatus_codable() throws {
        // Given
        let matched = MatchStatus.matched
        let notMatched = MatchStatus.notMatched
        let pending = MatchStatus.pending

        // When
        let encodedMatched = try JSONEncoder().encode(matched)
        let encodedNotMatched = try JSONEncoder().encode(notMatched)
        let encodedPending = try JSONEncoder().encode(pending)

        // Then
        XCTAssertEqual(String(data: encodedMatched, encoding: .utf8), "\"matched\"")
        XCTAssertEqual(String(data: encodedNotMatched, encoding: .utf8), "\"not_matched\"")
        XCTAssertEqual(String(data: encodedPending, encoding: .utf8), "\"pending\"")
    }

    func test_authResponse_withMatchStatus_matched() throws {
        // Given
        let json = """
        {
            "access_token": "token",
            "refresh_token": "refresh",
            "expires_in": 3600,
            "user": {
                "id": "user-uuid-001",
                "kakao_id": "1234567890",
                "email": "ward@example.com",
                "nickname": "어르신",
                "profile_image_url": null,
                "user_type": "ward",
                "created_at": "2024-01-01T00:00:00Z",
                "guardian_info": null,
                "ward_info": {
                    "phone_number": "010-1234-5678",
                    "linked_guardian": {
                        "id": "guardian-001",
                        "user_id": "user-001",
                        "nickname": "보호자",
                        "profile_image_url": null
                    },
                    "linked_organization": null
                }
            },
            "match_status": "matched",
            "match_message": null
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: json)

        // Then
        XCTAssertEqual(response.matchStatus, .matched)
        XCTAssertNil(response.matchMessage)
        XCTAssertNotNil(response.user.wardInfo?.linkedGuardian)
    }

    func test_authResponse_withMatchStatus_notMatched() throws {
        // Given
        let json = """
        {
            "access_token": "token",
            "refresh_token": "refresh",
            "expires_in": 3600,
            "user": {
                "id": "user-uuid-001",
                "kakao_id": "1234567890",
                "email": "ward@example.com",
                "nickname": "어르신",
                "profile_image_url": null,
                "user_type": "ward",
                "created_at": "2024-01-01T00:00:00Z",
                "guardian_info": null,
                "ward_info": null
            },
            "match_status": "not_matched",
            "match_message": "등록된 보호자 정보가 없습니다."
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder.apiDecoder.decode(AuthResponse.self, from: json)

        // Then
        XCTAssertEqual(response.matchStatus, .notMatched)
        XCTAssertEqual(response.matchMessage, "등록된 보호자 정보가 없습니다.")
    }
}
