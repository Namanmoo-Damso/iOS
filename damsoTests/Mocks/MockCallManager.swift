import Foundation
@testable import damso

final class MockCallManager: CallManagerProtocol {
    var reportIncomingCallCount = 0
    var answerCallCount = 0
    var endCallCount = 0

    var lastReportedUUID: UUID?
    var lastAnsweredUUID: UUID?
    var lastEndedUUID: UUID?

    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool,
        callId: String?,
        roomName: String?,
        completion: (@Sendable (Error?) -> Void)?
    ) {
        reportIncomingCallCount += 1
        lastReportedUUID = uuid
        completion?(nil)
    }

    func answerCall(uuid: UUID) {
        answerCallCount += 1
        lastAnsweredUUID = uuid
    }

    func endCall(uuid: UUID) {
        endCallCount += 1
        lastEndedUUID = uuid
    }
}
