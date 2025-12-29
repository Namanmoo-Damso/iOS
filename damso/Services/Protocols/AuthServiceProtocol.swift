import Foundation

protocol AuthServiceProtocol {
    func fetchApiToken() async throws -> String
    func fetchLiveKitToken(roomName: String) async throws -> String
}
