import Foundation
@testable import damso

final class MockAuthService: AuthServiceProtocol {
    var fetchApiTokenResult: Result<String, Error> = .success("mock-api-token")
    var fetchLiveKitTokenResult: Result<String, Error> = .success("mock-livekit-token")

    var fetchApiTokenCallCount = 0
    var fetchLiveKitTokenCallCount = 0
    var lastRoomName: String?

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
}
