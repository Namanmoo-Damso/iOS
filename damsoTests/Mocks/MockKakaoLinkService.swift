//
//  MockKakaoLinkService.swift
//  damsoTests
//
//  Created by Claude Code on 2024-12-30.
//

import Foundation
@testable import damso

@MainActor
final class MockKakaoLinkService: KakaoLinkServiceProtocol {

    // MARK: - Configurable Results

    var shareResult: Result<Void, Error> = .success(())
    var mockIsShareAvailable: Bool = true

    // MARK: - Call Tracking

    var shareInviteLinkCallCount = 0
    var lastGuardianId: String?
    var lastGuardianName: String?
    var lastWardEmail: String?

    // MARK: - KakaoLinkServiceProtocol

    var isShareAvailable: Bool {
        mockIsShareAvailable
    }

    func shareInviteLink(
        guardianId: String,
        guardianName: String,
        wardEmail: String
    ) async throws {
        shareInviteLinkCallCount += 1
        lastGuardianId = guardianId
        lastGuardianName = guardianName
        lastWardEmail = wardEmail

        switch shareResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Test Helpers

    func reset() {
        shareInviteLinkCallCount = 0
        lastGuardianId = nil
        lastGuardianName = nil
        lastWardEmail = nil
        shareResult = .success(())
        mockIsShareAvailable = true
    }
}
